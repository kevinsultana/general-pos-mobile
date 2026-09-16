import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../local/cloud_database.dart' show SyncEvent;
import '../local/app_database.dart' hide SyncEvent, SyncEventsCompanion;
import '../../core/constants/scale_constants.dart';
import '../../domain/models/printer_device.dart';
import 'api_client.dart';

/// Result of a push operation.
class SyncPushResult {
  final int received;
  final int synced;
  final int failed;
  final int skipped;

  const SyncPushResult({
    required this.received,
    required this.synced,
    required this.failed,
    required this.skipped,
  });

  factory SyncPushResult.empty() =>
      const SyncPushResult(received: 0, synced: 0, failed: 0, skipped: 0);

  bool get hasFailures => failed > 0;
}

/// Retry delay schedule in seconds: 2s, 5s, 15s, 30s, 60s.
const _retryDelays = [2, 5, 15, 30, 60];

/// Orchestrates push (mobile → server) and pull (server → mobile) sync.
class CloudSyncService {
  final dynamic _dao;
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final AppDatabase? _db;

  const CloudSyncService(this._dao, this._apiClient, this._tokenStorage, [this._db]);

  // ──────────────── Enqueue ────────────────

  /// Add a business event to the local sync queue.
  Future<void> enqueueEvent({
    required String storeId,
    required String deviceId,
    required String operation,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final id = const Uuid().v4();
    await _dao.insertRawEvent(
      id: id,
      storeId: storeId,
      deviceId: deviceId,
      entityType: _entityTypeFor(operation),
      entityId: entityId,
      operation: operation,
      payload: jsonEncode(payload),
      status: 'PENDING',
      createdAt: DateTime.now(),
    );
  }

  // ──────────────── Push ────────────────

  /// Push all PENDING events to the server.
  /// Returns a [SyncPushResult] summarizing what happened.
  Future<SyncPushResult> pushPendingEvents() async {
    final storeId = await _tokenStorage.getStoreId();
    final deviceId = await _tokenStorage.getDeviceId();
    if (storeId == null || deviceId == null) return SyncPushResult.empty();

    // 0. Recover stale PROCESSING events (stuck from a prior crash/abort)
    await _dao.resetStaleProcessing(storeId);

    final pending = await _dao.getPendingEvents(storeId, limit: 50);
    if (pending.isEmpty) return SyncPushResult.empty();

    // Mark all as PROCESSING before sending
    for (final e in pending) {
      await _dao.markProcessing(e.id);
    }

    try {
      final events = pending.map((e) => {
            'eventId': e.id,
            'deviceId': deviceId,
            'occurredAt': e.createdAt.toUtc().toIso8601String(),
            'operation': e.operation,
            'entityId': e.entityId,
            'payload': jsonDecode(e.payload),
            'clientVersion': '1.0.0',
          }).toList();

      final response = await _apiClient.post('/api/v1/sync/push', {'events': events});
      final data = response['data'] as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];

      // Update status for each event based on server response.
      // CONFLICT = the event was rejected because the server detected
      // a data conflict (e.g. another device concurrently mutated the same entity).
      for (final r in results) {
        final eventId = r['eventId'] as String;
        final status = r['status'] as String;

        if (status == 'SYNCED' || status == 'SKIPPED') {
          await _dao.markSynced(eventId);
        } else if (status == 'CONFLICT') {
          await _dao.markConflict(eventId);
        } else {
          await _dao.markFailed(eventId);
        }
      }

      return SyncPushResult(
        received: data['received'] as int? ?? pending.length,
        synced: data['synced'] as int? ?? 0,
        failed: data['failed'] as int? ?? 0,
        skipped: data['skipped'] as int? ?? 0,
      );
    } catch (e) {
      // Mark all as FAILED on network/server error
      for (final ev in pending) {
        await _dao.markFailed(ev.id);
      }
      rethrow;
    }
  }

  // ──────────────── Pull ────────────────

  /// Pull new events from the server since the last cursor.
  /// Returns the number of events received.
  Future<int> pullLatestEvents() async {
    final storeId = await _tokenStorage.getStoreId();
    final deviceId = await _tokenStorage.getDeviceId();
    if (storeId == null || deviceId == null) return 0;

    final cursorRow = await _dao.getCursor(storeId, deviceId);
    final cursor = cursorRow?.cursor.toString() ?? '0';

    final response = await _apiClient.get('/api/v1/sync/pull', queryParams: {
      'cursor': cursor,
      'deviceId': deviceId,
    });

    final data = response['data'] as Map<String, dynamic>;
    final events = (data['events'] as List<dynamic>?) ?? [];
    final nextCursor = data['nextCursor'] as String? ?? cursor;

    // Apply received events to local cloud cache
    for (final raw in events) {
      if (raw is Map<String, dynamic>) {
        await _applyReceivedEvent(storeId, raw);
      }
    }

    // Update cursor
    if (events.isNotEmpty) {
      await _dao.updateCursor(
          storeId, deviceId, BigInt.tryParse(nextCursor) ?? BigInt.zero);
    }

    return events.length;
  }

  /// Persists and dispatches a pulled event into the local cloud cache.
  Future<void> _applyReceivedEvent(
    String storeId,
    Map<String, dynamic> raw,
  ) async {
    final eventId = raw['id'] as String? ?? raw['eventId'] as String?;
    final eventDeviceId = raw['deviceId'] as String? ?? 'remote';
    final entityType = raw['entityType'] as String? ?? 'Unknown';
    final entityId = raw['entityId'] as String? ?? '';
    final operation = raw['operation'] as String? ?? '';
    final payloadRaw = raw['payload'];
    final payloadStr =
        payloadRaw is String ? payloadRaw : jsonEncode(payloadRaw);

    if (eventId != null) {
      // Record received event into cloud_cache sync log as SYNCED
      await _dao.insertRawEvent(
        id: eventId,
        storeId: storeId,
        deviceId: eventDeviceId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payloadStr,
        status: 'SYNCED',
        createdAt: DateTime.tryParse(raw['occurredAt'] as String? ?? '') ??
            DateTime.now(),
        syncedAt: DateTime.tryParse(raw['syncedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }

    // Process incoming operation
    await _dispatchOperation(storeId, operation, payloadRaw);
  }

  /// Dispatches the operation payload for downstream local caching.
  Future<void> _dispatchOperation(
    String storeId,
    String operation,
    dynamic payloadRaw,
  ) async {
    if (payloadRaw == null) return;
    final payload = payloadRaw is String
        ? jsonDecode(payloadRaw) as Map<String, dynamic>
        : (payloadRaw as Map<String, dynamic>);

    switch (operation) {
      case 'COMPLETE_TRANSACTION':
        await _handleCompleteTransaction(storeId, payload);
        break;
      case 'CANCEL_TRANSACTION':
        await _handleCancelTransaction(storeId, payload);
        break;
      case 'REFUND_TRANSACTION':
        await _handleRefundTransaction(storeId, payload);
        break;
      case 'ADJUST_STOCK':
        await _handleAdjustStock(storeId, payload);
        break;
      case 'CREATE_CATEGORY':
      case 'UPDATE_CATEGORY':
      case 'UPSERT_CATEGORY':
        await _handleCategoryUpsert(storeId, payload);
        break;
      case 'DELETE_CATEGORY':
        await _handleCategoryDelete(storeId, payload);
        break;
      case 'CREATE_PRODUCT':
      case 'UPDATE_PRODUCT':
      case 'UPSERT_PRODUCT':
        await _handleProductUpsert(storeId, payload);
        break;
      case 'DELETE_PRODUCT':
        await _handleProductDelete(storeId, payload);
        break;
      case 'CREATE_CUSTOMER':
      case 'UPDATE_CUSTOMER':
      case 'UPSERT_CUSTOMER':
        await _handleCustomerUpsert(storeId, payload);
        break;
      case 'DELETE_CUSTOMER':
        await _handleCustomerDelete(storeId, payload);
        break;
      case 'CREATE_PROMOTION':
      case 'UPDATE_PROMOTION':
      case 'UPSERT_PROMOTION':
        await _handlePromotionUpsert(storeId, payload);
        break;
      case 'DELETE_PROMOTION':
        await _handlePromotionDelete(storeId, payload);
        break;
      case 'CREATE_PRINTER':
      case 'UPDATE_PRINTER':
      case 'UPSERT_PRINTER':
        await _handlePrinterUpsert(storeId, payload);
        break;
      case 'DELETE_PRINTER':
        await _handlePrinterDelete(storeId, payload);
        break;
      case 'CREATE':
      case 'UPDATE': {
        final entityType = payload['entityType'] as String?;
        if (entityType == 'Product') {
          await _handleProductUpsert(storeId, payload);
        } else if (entityType == 'Category') {
          await _handleCategoryUpsert(storeId, payload);
        } else if (entityType == 'Promotion') {
          await _handlePromotionUpsert(storeId, payload);
        } else if (entityType == 'Customer') {
          await _handleCustomerUpsert(storeId, payload);
        } else if (entityType == 'Printer') {
          await _handlePrinterUpsert(storeId, payload);
        }
        break;
      }
      case 'DELETE': {
        final entityType = payload['entityType'] as String?;
        if (entityType == 'Product') {
          await _handleProductDelete(storeId, payload);
        } else if (entityType == 'Category') {
          await _handleCategoryDelete(storeId, payload);
        } else if (entityType == 'Promotion') {
          await _handlePromotionDelete(storeId, payload);
        } else if (entityType == 'Customer') {
          await _handleCustomerDelete(storeId, payload);
        } else if (entityType == 'Printer') {
          await _handlePrinterDelete(storeId, payload);
        }
        break;
      }
      default:
        break;
    }
  }

  /// Exposed for testing inbound dispatching logic.
  Future<void> dispatchOperationForTesting(
    String storeId,
    String operation,
    dynamic payloadRaw,
  ) =>
      _dispatchOperation(storeId, operation, payloadRaw);

  Future<void> _handleCompleteTransaction(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final items = payload['items'] as List<dynamic>?;
    final trxId = payload['transactionId'] as String? ?? payload['id'] as String?;
    if (items == null) return;

    for (final itemRaw in items) {
      if (itemRaw is! Map<String, dynamic>) continue;
      final productId = itemRaw['productId'] as String?;
      final quantity = (itemRaw['quantity'] as num?)?.toDouble() ?? 0.0;
      if (productId == null || quantity <= 0) continue;

      final prod = await db.productDao.getProductById(productId);
      if (prod != null) {
        final newStock = prod.stock - quantity.round();
        await db.productDao.updateStock(productId, newStock);

        // quantityDelta is stored with stockScale (1000) in Drift ledger.
        // Server payload sends raw unit quantity, so we scale it by stockScale.
        await db.stockMovementDao.recordMovement(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            storeId: storeId,
            productId: productId,
            variantId: Value(itemRaw['variantId'] as String?),
            type: 'SALE',
            quantityDelta: -toScaled(quantity, stockScale),
            referenceType: const Value('TRANSACTION'),
            referenceId: Value(trxId),
            reason: const Value('Remote Sync: Sale'),
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<void> _handleCancelTransaction(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final transactionId = payload['transactionId'] as String? ?? payload['id'] as String?;
    final reason = payload['reason'] as String? ?? 'Remote Sync: Cancelled';
    if (transactionId == null) return;

    final items = await db.transactionDao.getItemsByTransactionId(transactionId);
    if (items.isNotEmpty) {
      for (final item in items) {
        final prod = await db.productDao.getProductById(item.productId);
        if (prod != null) {
          final newStock = prod.stock + item.quantity.round();
          await db.productDao.updateStock(item.productId, newStock);

          await db.stockMovementDao.recordMovement(
            StockMovementsCompanion.insert(
              id: const Uuid().v4(),
              storeId: storeId,
              productId: item.productId,
              variantId: Value(item.variantId),
              type: 'CANCEL_REVERSAL',
              quantityDelta: toScaled(item.quantity, stockScale), // Scaled by 1000 in Drift ledger
              referenceType: const Value('TRANSACTION'),
              referenceId: Value(transactionId),
              reason: Value(reason),
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      await db.transactionDao.updateTransactionStatus(transactionId, 'CANCELLED');
    }
  }

  Future<void> _handleRefundTransaction(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final transactionId = payload['transactionId'] as String? ?? payload['id'] as String?;
    final reason = payload['reason'] as String? ?? 'Remote Sync: Refund';
    final refundedAt = DateTime.tryParse(payload['refundedAt'] as String? ?? '') ?? DateTime.now();
    final items = payload['items'] as List<dynamic>?;
    if (transactionId == null) return;

    if (items != null && items.isNotEmpty) {
      for (final itemRaw in items) {
        if (itemRaw is! Map<String, dynamic>) continue;
        final productId = itemRaw['productId'] as String?;
        final quantity = (itemRaw['quantity'] as num?)?.toDouble() ?? 0.0;
        if (productId == null || quantity <= 0) continue;

        final prod = await db.productDao.getProductById(productId);
        if (prod != null) {
          final newStock = prod.stock + quantity.round();
          await db.productDao.updateStock(productId, newStock);

          await db.stockMovementDao.recordMovement(
            StockMovementsCompanion.insert(
              id: const Uuid().v4(),
              storeId: storeId,
              productId: productId,
              variantId: Value(itemRaw['variantId'] as String?),
              type: 'REFUND_REVERSAL',
              quantityDelta: toScaled(quantity, stockScale),
              referenceType: const Value('TRANSACTION'),
              referenceId: Value(transactionId),
              reason: Value(reason),
              createdAt: refundedAt,
            ),
          );
        }
      }
    }

    final isFullRefund = payload['isFullRefund'] as bool? ?? (payload['status'] == 'REFUNDED');
    final newStatus = isFullRefund ? 'REFUNDED' : 'PARTIALLY_REFUNDED';
    await db.transactionDao.updateTransactionRefunded(transactionId, newStatus, refundedAt);
  }

  Future<void> _handleAdjustStock(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final productId = payload['productId'] as String?;
    final variantId = payload['variantId'] as String?;
    final deltaNum = (payload['quantityDelta'] ?? payload['delta']) as num?;
    final reason = payload['reason'] as String? ?? 'Remote Sync: Stock Adjustment';
    if (productId == null || deltaNum == null) return;

    final delta = deltaNum.toInt();
    if (variantId != null && variantId.isNotEmpty) {
      final variants = await db.productDao.getVariantsByProductId(productId);
      final variant = variants.where((v) => v.id == variantId).firstOrNull;
      if (variant != null) {
        final newVariantStock = variant.stock + delta;
        await db.productDao.updateVariantStock(variantId, newVariantStock);
      }
    }

    final prod = await db.productDao.getProductById(productId);
    if (prod != null) {
      final newStock = prod.stock + delta;
      await db.productDao.updateStock(productId, newStock);

      await db.stockMovementDao.recordMovement(
        StockMovementsCompanion.insert(
          id: const Uuid().v4(),
          storeId: storeId,
          productId: productId,
          variantId: Value(variantId),
          type: 'ADJUSTMENT',
          quantityDelta: toScaled(delta.toDouble(), stockScale), // Scaled by 1000 in Drift ledger
          referenceType: const Value('ADJUSTMENT'),
          reason: Value(reason),
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _handleCategoryUpsert(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String? ?? payload['categoryId'] as String?;
    final name = payload['name'] as String?;
    if (id == null || name == null) return;

    await db.categoryDao.insertCategory(
      CategoriesCompanion.insert(
        id: id,
        storeId: storeId,
        name: name,
        createdAt: DateTime.tryParse(payload['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      ),
    );
  }

  Future<void> _handleCategoryDelete(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String? ?? payload['categoryId'] as String? ?? payload['entityId'] as String?;
    if (id == null) return;
    await db.categoryDao.deleteCategory(id);
  }

  Future<void> _handleProductUpsert(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String?;
    final name = payload['name'] as String?;
    final categoryId = payload['categoryId'] as String?;
    final sellingPrice = (payload['sellingPrice'] as num?)?.toInt() ?? 0;
    final cost = (payload['cost'] as num?)?.toInt() ?? 0;
    final stock = (payload['stock'] as num?)?.toInt() ?? 0;
    final sku = payload['sku'] as String?;
    final barcode = payload['barcode'] as String?;

    if (id == null || name == null || categoryId == null) return;

    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        id: id,
        storeId: storeId,
        categoryId: categoryId,
        name: name,
        sellingPrice: sellingPrice,
        cost: cost,
        stock: stock,
        sku: Value(sku),
        barcode: Value(barcode),
        active: const Value(true),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final rawVariants = payload['variants'] as List<dynamic>?;
    if (rawVariants != null) {
      for (final v in rawVariants) {
        if (v is! Map<String, dynamic>) continue;
        final vId = v['id'] as String?;
        final vName = v['name'] as String?;
        if (vId == null || vName == null) continue;

        await db.productDao.insertVariant(
          ProductVariantsCompanion.insert(
            id: vId,
            productId: id,
            name: vName,
            cost: (v['cost'] as num?)?.toInt() ?? cost,
            sellingPrice: (v['sellingPrice'] as num?)?.toInt() ?? sellingPrice,
            stock: (v['stock'] as num?)?.toInt() ?? 0,
            sku: Value(v['sku'] as String?),
            barcode: Value(v['barcode'] as String?),
            active: Value(v['active'] as bool? ?? true),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<void> _handlePromotionUpsert(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;

    final id = payload['id'] as String?;
    final name = payload['name'] as String?;
    if (id == null || name == null) return;

    final code = payload['code'] as String?;
    final rawType = payload['type'] ?? payload['discountType'] ?? 'PERCENTAGE';
    final discountType = rawType.toString().trim().toUpperCase() == 'FIXED'
        ? 'FIXED_AMOUNT'
        : rawType.toString().trim().toUpperCase();

    // Scale is 1:1 IDR whole Rupiah (no multiplying or dividing by 100/1000)
    final rawVal = payload['value'] ?? payload['discountValue'] ?? 0;
    final discountValue = (rawVal is num ? rawVal : num.tryParse(rawVal.toString()) ?? 0).round();

    final rawMin = payload['minimumPurchase'] ?? payload['minSpend'] ?? 0;
    final minSpend = (rawMin is num ? rawMin : num.tryParse(rawMin.toString()) ?? 0).round();

    final startDateStr = payload['startAt'] ?? payload['startDate'];
    final startDate = startDateStr != null ? DateTime.tryParse(startDateStr.toString()) : null;

    final endDateStr = payload['endAt'] ?? payload['endDate'];
    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr.toString()) : null;

    final productId = payload['productId'] as String?;
    final active = (payload['active'] as bool?) ?? true;

    await db.promotionDao.insertPromotion(
      PromotionsCompanion(
        id: Value(id),
        storeId: Value(storeId),
        name: Value(name),
        code: Value(code?.toUpperCase()),
        discountType: Value(discountType),
        discountValue: Value(discountValue),
        minSpend: Value(minSpend),
        startDate: Value(startDate),
        endDate: Value(endDate),
        productId: Value(productId),
        active: Value(active),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _handleProductDelete(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String? ?? payload['productId'] as String? ?? payload['entityId'] as String?;
    if (id == null) return;
    await db.productDao.deleteProduct(id);
  }

  Future<void> _handlePromotionDelete(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String? ?? payload['promotionId'] as String? ?? payload['entityId'] as String?;
    if (id == null) return;
    await db.promotionDao.deletePromotion(id);
  }

  Future<void> _handleCustomerUpsert(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String?;
    final name = payload['name'] as String?;
    if (id == null || name == null) return;

    final phone = payload['phone'] as String?;
    final email = payload['email'] as String?;
    final notes = payload['notes'] as String?;
    final createdAt = DateTime.tryParse(payload['createdAt'] as String? ?? '') ?? DateTime.now();
    final updatedAt = DateTime.tryParse(payload['updatedAt'] as String? ?? '') ?? DateTime.now();

    await db.customerDao.insertCustomer(
      CustomersCompanion.insert(
        id: id,
        storeId: storeId,
        name: name,
        phone: Value(phone),
        email: Value(email),
        notes: Value(notes),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Future<void> _handleCustomerDelete(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String? ?? payload['customerId'] as String? ?? payload['entityId'] as String?;
    if (id == null) return;
    await db.customerDao.deleteCustomer(id);
  }

  Future<void> _handlePrinterUpsert(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String?;
    final name = payload['name'] as String?;
    if (id == null || name == null) return;

    final configRaw = payload['configuration'];
    final configMap = PrinterDevice.decodeConfiguration(configRaw);
    final paperSizeStr = payload['paperSize'] as String? ??
        PrinterDevice.decodePaperSize(configRaw).toDbString();
    configMap['paperSize'] =
        PrinterPaperSize.fromString(paperSizeStr).toConfigString();

    await db.printerDao.upsertPrinter(
      PrintersCompanion(
        id: Value(id),
        storeId: Value(storeId),
        name: Value(name),
        connectionType:
            Value(payload['connectionType']?.toString() ?? 'BLUETOOTH'),
        addressReference: Value(payload['addressReference']?.toString()),
        role: Value(payload['role']?.toString() ?? 'RECEIPT'),
        receiptCopies: Value((payload['receiptCopies'] as num?)?.toInt() ?? 1),
        kitchenCopies: Value((payload['kitchenCopies'] as num?)?.toInt() ?? 1),
        autoPrint: Value(payload['autoPrint'] as bool? ?? false),
        active: Value(payload['active'] as bool? ?? true),
        configuration: Value(jsonEncode(configMap)),
        createdAt: Value(DateTime.tryParse(payload['createdAt']?.toString() ?? '') ??
            DateTime.now()),
        updatedAt: Value(DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ??
            DateTime.now()),
      ),
    );
  }

  Future<void> _handlePrinterDelete(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final db = _db;
    if (db == null) return;
    final id = payload['id'] as String? ?? payload['printerId'] as String?;
    if (id == null) return;
    await db.printerDao.deletePrinter(id);
  }

  SyncEvent _mapToSyncEvent(dynamic e) {
    if (e is SyncEvent) return e;
    return SyncEvent(
      id: e.id as String,
      storeId: e.storeId as String,
      deviceId: e.deviceId as String,
      entityType: e.entityType as String,
      entityId: e.entityId as String,
      operation: e.operation as String,
      payload: e.payload as String,
      status: e.status as String,
      attemptCount: e.attemptCount as int,
      lastAttemptAt: e.lastAttemptAt as DateTime?,
      createdAt: e.createdAt as DateTime,
      syncedAt: e.syncedAt as DateTime?,
    );
  }

  // ──────────────── Get Failed / Conflict ────────────────

  /// Get all failed events for this store.
  Future<List<SyncEvent>> getFailedEvents(String storeId) async {
    final list = await _dao.getFailedEvents(storeId);
    return (list as List).map(_mapToSyncEvent).toList();
  }

  /// Get all conflict events for this store.
  Future<List<SyncEvent>> getConflictEvents(String storeId) async {
    final list = await _dao.getConflictEvents(storeId);
    return (list as List).map(_mapToSyncEvent).toList();
  }

  // ──────────────── Retry ────────────────

  /// Retry all FAILED events.
  Future<SyncPushResult> retryFailed() async {
    final storeId = await _tokenStorage.getStoreId();
    if (storeId == null) return SyncPushResult.empty();

    final failed = await _dao.getFailedEvents(storeId);
    for (final e in failed) {
      await _dao.retryFailed(e.id);
    }
    return pushPendingEvents();
  }

  /// Retry all CONFLICT events by resetting them to PENDING.
  /// The server is authoritative — conflicts are resolved by re-sending
  /// and accepting whatever the server returns.
  Future<SyncPushResult> retryConflicts() async {
    final storeId = await _tokenStorage.getStoreId();
    if (storeId == null) return SyncPushResult.empty();

    final conflicts = await _dao.getConflictEvents(storeId);
    for (final e in conflicts) {
      await _dao.retryFailed(e.id); // retryFailed resets to PENDING
    }
    return pushPendingEvents();
  }

  /// Reset stale PROCESSING events (stuck > threshold) back to PENDING.
  /// Safe to call on app startup to recover from crash/network abort.
  Future<int> resetStaleProcessing({Duration staleThreshold = const Duration(minutes: 5)}) async {
    final storeId = await _tokenStorage.getStoreId();
    if (storeId == null) return 0;
    return _dao.resetStaleProcessing(storeId, staleThreshold: staleThreshold);
  }

  // ──────────────── Streams ────────────────

  /// Stream of pending event count for this store.
  Stream<int> watchPendingCount(String storeId) =>
      _dao.watchPendingCount(storeId);

  // ──────────────── Helpers ────────────────

  String entityTypeFor(String operation) => _entityTypeFor(operation);

  String _entityTypeFor(String operation) {
    if (operation.contains('TRANSACTION')) return 'Transaction';
    if (operation.contains('STOCK')) return 'StockMovement';
    if (operation.contains('PRODUCT')) return 'Product';
    if (operation.contains('CATEGORY')) return 'Category';
    if (operation.contains('CUSTOMER')) return 'Customer';
    if (operation.contains('PROMOTION')) return 'Promotion';
    if (operation.contains('PRINTER')) return 'Printer';
    return 'Unknown';
  }

  /// Returns the retry delay for the given attempt count (0-indexed) with full jitter
  /// to prevent thundering herd when multiple devices reconnect simultaneously.
  static Duration retryDelay(int attemptCount, [Random? random]) {
    final idx = attemptCount.clamp(0, _retryDelays.length - 1);
    final baseMs = _retryDelays[idx] * 1000;
    final rnd = random ?? Random();
    final jitterMs = rnd.nextInt(1500); // 0-1500ms random jitter
    return Duration(milliseconds: baseMs + jitterMs);
  }
}
