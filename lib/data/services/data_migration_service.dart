import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import 'api_client.dart';
import 'cloud_sync_service.dart' show CloudSyncEventData;
import 'data_reset_service.dart';

/// Progress info during migration
class MigrationProgress {
  final String step;
  final int totalItems;
  final int processedItems;

  const MigrationProgress({
    required this.step,
    required this.totalItems,
    required this.processedItems,
  });
}

/// Migrates local offline POS database to the Cloud backend (PRO Plan)
/// and copies data into the Cloud Cache SQLite database.
class DataMigrationService {
  final AppDatabase _localDb;
  final AppDatabase _cloudDb;
  final ApiClient apiClient;
  final TokenStorage _tokenStorage;
  final DataResetService _resetService;

  DataMigrationService({
    required AppDatabase localDb,
    required AppDatabase cloudDb,
    required this.apiClient,
    required TokenStorage tokenStorage,
  })  : _localDb = localDb,
        _cloudDb = cloudDb,
        _tokenStorage = tokenStorage,
        _resetService = DataResetService(
          localDb: localDb,
          cloudDb: cloudDb,
          tokenStorage: tokenStorage,
        );

  /// Migrates and pushes all local offline entities to the cloud server via /api/v1/sync/push,
  /// then populates cloud_cache.sqlite with the synced entities.
  Future<void> migrateAndPushLocalDataToCloud(
    String storeId, {
    void Function(MigrationProgress)? onProgress,
  }) async {
    final deviceId = (await _tokenStorage.getDeviceId()) ?? const Uuid().v4();
    final events = <Map<String, dynamic>>[];

    await _localDb.storeDao.healAllOrphanRecords(storeId);

    // 1. Read & Format Categories
    onProgress?.call(const MigrationProgress(
      step: 'Membaca kategori lokal...',
      totalItems: 0,
      processedItems: 0,
    ));
    final categories = await _localDb.categoryDao.getAllCategories(storeId);
    for (final cat in categories) {
      events.add(CloudSyncEventData(
        eventId: const Uuid().v4(),
        deviceId: deviceId,
        occurredAt: cat.createdAt.toUtc().toIso8601String(),
        operation: 'CREATE_CATEGORY',
        entityId: cat.id,
        payload: {
          'id': cat.id,
          'name': cat.name,
          'active': true,
        },
      ).toJson());
    }

    // 2. Read & Format Products & Variants
    onProgress?.call(MigrationProgress(
      step: 'Membaca produk lokal (${categories.length} kategori disiapkan)...',
      totalItems: 0,
      processedItems: 0,
    ));
    final products = await _localDb.productDao.getAllProducts(storeId);
    for (final prod in products) {
      final variants = await _localDb.productDao.getVariantsByProductId(prod.id);
      events.add(CloudSyncEventData(
        eventId: const Uuid().v4(),
        deviceId: deviceId,
        occurredAt: prod.createdAt.toUtc().toIso8601String(),
        operation: 'CREATE_PRODUCT',
        entityId: prod.id,
        payload: {
          'id': prod.id,
          'name': prod.name,
          'sku': prod.sku,
          'barcode': prod.barcode,
          'categoryId': prod.categoryId,
          'cost': prod.cost,
          'sellingPrice': prod.sellingPrice,
          'stock': prod.stock,
          'lowStockThreshold': prod.lowStockThreshold,
          'active': prod.active,
          'discontinued': prod.discontinued,
          'variants': variants
              .map((v) => {
                    'id': v.id,
                    'name': v.name,
                    'sku': v.sku,
                    'barcode': v.barcode,
                    'cost': v.cost,
                    'sellingPrice': v.sellingPrice,
                    'stock': v.stock,
                    'lowStockThreshold': v.lowStockThreshold,
                    'active': v.active,
                  })
              .toList(),
        },
      ).toJson());
    }

    // 3. Read & Format Customers
    onProgress?.call(MigrationProgress(
      step: 'Membaca data pelanggan (${products.length} produk disiapkan)...',
      totalItems: 0,
      processedItems: 0,
    ));
    final customers = await _localDb.customerDao.getAllCustomers(storeId);
    for (final cust in customers) {
      events.add(CloudSyncEventData(
        eventId: const Uuid().v4(),
        deviceId: deviceId,
        occurredAt: cust.createdAt.toUtc().toIso8601String(),
        operation: 'CREATE_CUSTOMER',
        entityId: cust.id,
        payload: {
          'id': cust.id,
          'name': cust.name,
          'phone': cust.phone,
          'email': cust.email,
          'notes': cust.notes,
        },
      ).toJson());
    }

    // 4. Read & Format Promotions
    final promotions = await _localDb.promotionDao.getAllPromotions(storeId);
    for (final promo in promotions) {
      events.add(CloudSyncEventData(
        eventId: const Uuid().v4(),
        deviceId: deviceId,
        occurredAt: (promo.startDate ?? DateTime.now()).toUtc().toIso8601String(),
        operation: 'CREATE_PROMOTION',
        entityId: promo.id,
        payload: {
          'id': promo.id,
          'name': promo.name,
          'code': promo.code,
          'discountType': promo.discountType,
          'discountValue': promo.discountValue,
          'minSpend': promo.minSpend,
          'startDate': promo.startDate?.toUtc().toIso8601String(),
          'endDate': promo.endDate?.toUtc().toIso8601String(),
          'productId': promo.productId,
          'active': promo.active,
        },
      ).toJson());
    }

    // 5. Read & Format Completed Transactions
    onProgress?.call(MigrationProgress(
      step: 'Membaca riwayat transaksi lokal...',
      totalItems: events.length,
      processedItems: events.length,
    ));
    final transactions =
        await _localDb.transactionDao.getTransactionsByStore(storeId, limit: 1000);
    for (final tx in transactions) {
      if (tx.status != 'COMPLETED') continue;
      final items = await _localDb.transactionDao.getItemsByTransactionId(tx.id);
      final payments = await _localDb.paymentDao.getPaymentsByTransactionId(tx.id);

      events.add(CloudSyncEventData(
        eventId: const Uuid().v4(),
        deviceId: deviceId,
        occurredAt: tx.createdAt.toUtc().toIso8601String(),
        operation: 'COMPLETE_TRANSACTION',
        entityId: tx.id,
        payload: {
          'id': tx.id,
          'transactionNumber': tx.transactionNumber,
          'customerId': tx.customerId,
          'promotionId': tx.promotionId,
          'orderType': tx.orderType,
          'queueNumber': tx.queueNumber,
          'subtotal': tx.subtotal,
          'discountType': tx.discountType,
          'discountValue': tx.discountValue,
          'discountTotal': tx.discountTotal,
          'roundingAmount': tx.roundingAmount,
          'total': tx.total,
          'status': tx.status,
          'createdAt': tx.createdAt.toUtc().toIso8601String(),
          'completedAt':
              (tx.completedAt ?? tx.createdAt).toUtc().toIso8601String(),
          'items': items
              .map((it) => {
                    'id': it.id,
                    'productId': it.productId,
                    'productName': it.productNameSnapshot,
                    'variantId': it.variantId,
                    'quantity': it.quantity,
                    'unitPrice': it.unitPrice,
                    'discountType': it.discountType,
                    'discountValue': it.discountValue,
                    'discountAmount': it.discountAmount,
                    'subtotal': it.subtotal,
                    'total': it.total,
                  })
              .toList(),
          'payments': payments
              .map((p) => {
                    'id': p.id,
                    'paymentMethodId': p.paymentMethodId,
                    'amount': p.amount,
                    'roundingAmount': p.roundingAmount,
                    'metadata':
                        p.metadata != null ? jsonDecode(p.metadata!) : null,
                  })
              .toList(),
        },
      ).toJson());
    }

    // 6. Read & Format Stock Adjustments
    final stockMovements =
        await _localDb.stockMovementDao.getRecentMovements(storeId, limit: 1000);
    for (final sm in stockMovements) {
      if (sm.type == 'ADJUSTMENT') {
        events.add(CloudSyncEventData(
          eventId: const Uuid().v4(),
          deviceId: deviceId,
          occurredAt: sm.createdAt.toUtc().toIso8601String(),
          operation: 'ADJUST_STOCK',
          entityId: sm.id,
          payload: {
            'id': sm.id,
            'productId': sm.productId,
            'variantId': sm.variantId,
            'quantityDelta': sm.quantityDelta,
            'reason': sm.reason ?? 'Penyesuaian stok offline',
          },
        ).toJson());
      }
    }

    // 7. Push events in chunks to /api/v1/sync/push
    if (events.isNotEmpty) {
      onProgress?.call(MigrationProgress(
        step: 'Mengunggah ${events.length} data ke Cloud Server...',
        totalItems: events.length,
        processedItems: 0,
      ));

      const chunkSize = 50;
      for (int i = 0; i < events.length; i += chunkSize) {
        final end =
            (i + chunkSize < events.length) ? i + chunkSize : events.length;
        final chunk = events.sublist(i, end);

        try {
          await apiClient.post('/api/v1/sync/push', {'events': chunk});
        } catch (_) {
          // Continue best-effort for remaining batches
        }

        onProgress?.call(MigrationProgress(
          step: 'Mengunggah ke Cloud... ($end/${events.length})',
          totalItems: events.length,
          processedItems: end,
        ));
      }
    }

    // 8. Copy Entities to cloud_cache.sqlite (_cloudDb)
    onProgress?.call(const MigrationProgress(
      step: 'Menyelaraskan cache data Cloud...',
      totalItems: 1,
      processedItems: 0,
    ));

    // Store
    final localStore = await _localDb.storeDao.getStoreById(storeId);
    if (localStore != null) {
      await _cloudDb.storeDao.ensureStoreWithId(
        id: localStore.id,
        name: localStore.name,
        subscriptionPlan: 'PRO',
        subscriptionStatus: 'ACTIVE',
      );
    }

    // Categories
    for (final cat in categories) {
      try {
        await _cloudDb.categoryDao.insertCategory(
          CategoriesCompanion.insert(
            id: cat.id,
            storeId: storeId,
            name: cat.name,
            createdAt: cat.createdAt,
            updatedAt: cat.updatedAt,
          ),
        );
      } catch (_) {}
    }

    // Products & Variants
    for (final prod in products) {
      try {
        await _cloudDb.productDao.insertProduct(
          ProductsCompanion.insert(
            id: prod.id,
            storeId: storeId,
            categoryId: prod.categoryId,
            name: prod.name,
            sku: Value(prod.sku),
            barcode: Value(prod.barcode),
            cost: prod.cost,
            sellingPrice: prod.sellingPrice,
            stock: prod.stock,
            lowStockThreshold: Value(prod.lowStockThreshold),
            imageReference: Value(prod.imageReference),
            active: Value(prod.active),
            discontinued: Value(prod.discontinued),
            createdAt: prod.createdAt,
            updatedAt: prod.updatedAt,
          ),
        );
        final variants =
            await _localDb.productDao.getVariantsByProductId(prod.id);
        for (final v in variants) {
          await _cloudDb.productDao.insertVariant(
            ProductVariantsCompanion.insert(
              id: v.id,
              productId: v.productId,
              name: v.name,
              sku: Value(v.sku),
              barcode: Value(v.barcode),
              cost: v.cost,
              sellingPrice: v.sellingPrice,
              stock: v.stock,
              lowStockThreshold: Value(v.lowStockThreshold),
              active: Value(v.active),
              createdAt: v.createdAt,
              updatedAt: v.updatedAt,
            ),
          );
        }
      } catch (_) {}
    }

    // Customers
    for (final cust in customers) {
      try {
        await _cloudDb.customerDao.insertCustomer(
          CustomersCompanion.insert(
            id: cust.id,
            storeId: storeId,
            name: cust.name,
            phone: Value(cust.phone),
            email: Value(cust.email),
            notes: Value(cust.notes),
            createdAt: cust.createdAt,
            updatedAt: cust.updatedAt,
          ),
        );
      } catch (_) {}
    }

    // Promotions
    for (final promo in promotions) {
      try {
        await _cloudDb.promotionDao.insertPromotion(
          PromotionsCompanion.insert(
            id: promo.id,
            storeId: storeId,
            name: promo.name,
            code: Value(promo.code),
            discountType: promo.discountType,
            discountValue: promo.discountValue,
            minSpend: Value(promo.minSpend),
            startDate: Value(promo.startDate),
            endDate: Value(promo.endDate),
            productId: Value(promo.productId),
            active: Value(promo.active),
            createdAt: promo.createdAt,
            updatedAt: promo.updatedAt,
          ),
        );
      } catch (_) {}
    }

    // Transactions, Items, Payments
    for (final tx in transactions) {
      try {
        await _cloudDb.transactionDao.insertTransaction(
          TransactionsCompanion.insert(
            id: tx.id,
            storeId: storeId,
            transactionNumber: tx.transactionNumber,
            customerId: Value(tx.customerId),
            promotionId: Value(tx.promotionId),
            orderType: Value(tx.orderType),
            queueNumber: Value(tx.queueNumber),
            subtotal: tx.subtotal,
            discountType: Value(tx.discountType),
            discountValue: Value(tx.discountValue),
            discountTotal: Value(tx.discountTotal),
            roundingAmount: Value(tx.roundingAmount),
            total: tx.total,
            paidTotal: Value(tx.paidTotal),
            status: tx.status,
            completedAt: Value(tx.completedAt),
            createdAt: tx.createdAt,
            updatedAt: tx.updatedAt,
          ),
        );
        final items =
            await _localDb.transactionDao.getItemsByTransactionId(tx.id);
        for (final item in items) {
          await _cloudDb.transactionDao.insertTransactionItem(
            TransactionItemsCompanion.insert(
              id: item.id,
              transactionId: item.transactionId,
              productId: item.productId,
              variantId: Value(item.variantId),
              productNameSnapshot: item.productNameSnapshot,
              variantNameSnapshot: Value(item.variantNameSnapshot),
              skuSnapshot: Value(item.skuSnapshot),
              barcodeSnapshot: Value(item.barcodeSnapshot),
              unitCostSnapshot: item.unitCostSnapshot,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discountType: Value(item.discountType),
              discountValue: Value(item.discountValue),
              discountAmount: Value(item.discountAmount),
              subtotal: item.subtotal,
              total: item.total,
              createdAt: item.createdAt,
            ),
          );
        }
        final payments =
            await _localDb.paymentDao.getPaymentsByTransactionId(tx.id);
        for (final p in payments) {
          await _cloudDb.paymentDao.insertPayment(
            PaymentsCompanion.insert(
              id: p.id,
              transactionId: p.transactionId,
              paymentMethodId: p.paymentMethodId,
              amount: p.amount,
              roundingAmount: Value(p.roundingAmount),
              status: p.status,
              metadata: Value(p.metadata),
              paidAt: Value(p.paidAt),
              createdAt: p.createdAt,
            ),
          );
        }
      } catch (_) {}
    }

    // Stock Movements
    for (final sm in stockMovements) {
      try {
        await _cloudDb.stockMovementDao.recordMovement(
          StockMovementsCompanion.insert(
            id: sm.id,
            storeId: storeId,
            productId: sm.productId,
            variantId: Value(sm.variantId),
            type: sm.type,
            quantityDelta: sm.quantityDelta,
            unitCost: Value(sm.unitCost),
            referenceType: Value(sm.referenceType),
            referenceId: Value(sm.referenceId),
            reason: Value(sm.reason),
            createdById: Value(sm.createdById),
            createdAt: sm.createdAt,
          ),
        );
      } catch (_) {}
    }

    // 9. Update TokenStorage flags
    await _tokenStorage.setProMigrated(true);
    await _tokenStorage.setCloudMode(true);
    await _tokenStorage.setTier('PRO');
    await _tokenStorage.setCanCloudSync(true);

    onProgress?.call(const MigrationProgress(
      step: 'Migrasi ke Cloud PRO Selesai!',
      totalItems: 1,
      processedItems: 1,
    ));
  }

  /// Backward-compatible alias for existing calls
  Future<void> migrateLocalToCloud({
    required String localStoreId,
    required String cloudStoreId,
    void Function(MigrationProgress)? onProgress,
  }) async {
    await migrateAndPushLocalDataToCloud(cloudStoreId, onProgress: onProgress);
    await _resetService.clearLocalDatabaseOnly();
  }
}
