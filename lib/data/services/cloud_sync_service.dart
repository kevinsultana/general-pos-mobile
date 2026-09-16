import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../local/daos/cloud_sync_event_dao.dart';
import '../local/cloud_database.dart' show SyncEvent, SyncEventsCompanion;
import '../local/app_database.dart' hide SyncEvent, SyncEventsCompanion;
import '../../core/constants/scale_constants.dart';
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
  final CloudSyncEventDao _dao;
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
    await _dao.insertEvent(
      SyncEventsCompanion.insert(
        id: id,
        storeId: storeId,
        deviceId: deviceId,
        entityType: _entityTypeFor(operation),
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        status: 'PENDING',
        createdAt: DateTime.now(),
      ),
    );
  }

  // ──────────────── Push ────────────────

  /// Push all PENDING events to the server.
  /// Returns a [SyncPushResult] summarizing what happened.
  Future<SyncPushResult> pushPendingEvents() async {
    final storeId = await _tokenStorage.getStoreId();
    final deviceId = await _tokenStorage.getDeviceId();
    if (storeId == null || deviceId == null) return SyncPushResult.empty();

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
            'occurredAt': e.createdAt.toIso8601String(),
            'operation': e.operation,
            'entityId': e.entityId,
            'payload': jsonDecode(e.payload),
            'clientVersion': '1.0.0',
          }).toList();

      final response = await _apiClient.post('/api/v1/sync/push', {'events': events});
      final data = response['data'] as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];

      // Update status for each event
      for (final r in results) {
        final eventId = r['eventId'] as String;
        final status = r['status'] as String;

        if (status == 'SYNCED' || status == 'SKIPPED') {
          await _dao.markSynced(eventId);
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
      await _dao.insertEvent(
        SyncEventsCompanion.insert(
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
          syncedAt: Value(
            DateTime.tryParse(raw['syncedAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        ),
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
      case 'CREATE_PRODUCT':
      case 'UPDATE_PRODUCT':
        await _handleProductUpsert(storeId, payload);
        break;
      case 'CREATE_PROMOTION':
      case 'UPDATE_PROMOTION':
      case 'UPSERT_PROMOTION':
        await _handlePromotionUpsert(storeId, payload);
        break;
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
      final quantity = (itemRaw['quantity'] as num?)?.toInt() ?? 0;
      if (productId == null || quantity <= 0) continue;

      final prod = await db.productDao.getProductById(productId);
      if (prod != null) {
        final newStock = prod.stock - quantity;
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
            quantityDelta: -toScaled(quantity.toDouble(), stockScale),
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
          final newStock = prod.stock + item.quantity;
          await db.productDao.updateStock(item.productId, newStock);

          await db.stockMovementDao.recordMovement(
            StockMovementsCompanion.insert(
              id: const Uuid().v4(),
              storeId: storeId,
              productId: item.productId,
              variantId: Value(item.variantId),
              type: 'CANCEL_REVERSAL',
              quantityDelta: toScaled(item.quantity.toDouble(), stockScale), // Scaled by 1000 in Drift ledger
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
        final quantity = (itemRaw['quantity'] as num?)?.toInt() ?? 0;
        if (productId == null || quantity <= 0) continue;

        final prod = await db.productDao.getProductById(productId);
        if (prod != null) {
          final newStock = prod.stock + quantity;
          await db.productDao.updateStock(productId, newStock);

          await db.stockMovementDao.recordMovement(
            StockMovementsCompanion.insert(
              id: const Uuid().v4(),
              storeId: storeId,
              productId: productId,
              variantId: Value(itemRaw['variantId'] as String?),
              type: 'REFUND_REVERSAL',
              quantityDelta: toScaled(quantity.toDouble(), stockScale),
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
    final deltaNum = (payload['quantityDelta'] ?? payload['delta']) as num?;
    final reason = payload['reason'] as String? ?? 'Remote Sync: Stock Adjustment';
    if (productId == null || deltaNum == null) return;

      final delta = deltaNum.toInt();
      final prod = await db.productDao.getProductById(productId);
      if (prod != null) {
        final newStock = prod.stock + delta;
        await db.productDao.updateStock(productId, newStock);

        await db.stockMovementDao.recordMovement(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            storeId: storeId,
            productId: productId,
            type: 'ADJUSTMENT',
            quantityDelta: toScaled(delta.toDouble(), stockScale), // Scaled by 1000 in Drift ledger
            referenceType: const Value('ADJUSTMENT'),
            reason: Value(reason),
            createdAt: DateTime.now(),
          ),
        );
      }
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

  // ──────────────── Get Failed ────────────────

  /// Get all failed events for this store.
  Future<List<SyncEvent>> getFailedEvents(String storeId) =>
      _dao.getFailedEvents(storeId);

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

  // ──────────────── Streams ────────────────

  /// Stream of pending event count for this store.
  Stream<int> watchPendingCount(String storeId) =>
      _dao.watchPendingCount(storeId);

  // ──────────────── Helpers ────────────────

  String _entityTypeFor(String operation) {
    switch (operation) {
      case 'COMPLETE_TRANSACTION':
      case 'CANCEL_TRANSACTION':
      case 'REFUND_TRANSACTION':
        return 'Transaction';
      case 'ADJUST_STOCK':
        return 'StockMovement';
      case 'CREATE_PROMOTION':
      case 'UPDATE_PROMOTION':
      case 'UPSERT_PROMOTION':
        return 'Promotion';
      default:
        return 'Unknown';
    }
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
