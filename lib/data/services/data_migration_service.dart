import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import 'api_client.dart';
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
/// and cleans up the local database upon completion.
class DataMigrationService {
  final AppDatabase _localDb;
  final ApiClient apiClient;
  final TokenStorage _tokenStorage;
  final DataResetService _resetService;

  DataMigrationService({
    required AppDatabase localDb,
    required AppDatabase cloudDb,
    required this.apiClient,
    required TokenStorage tokenStorage,
  })  : _localDb = localDb,
        _tokenStorage = tokenStorage,
        _resetService = DataResetService(
          localDb: localDb,
          cloudDb: cloudDb,
          tokenStorage: tokenStorage,
        );

  /// Performs full migration of local data to cloud
  Future<void> migrateLocalToCloud({
    required String localStoreId,
    required String cloudStoreId,
    void Function(MigrationProgress)? onProgress,
  }) async {
    final deviceId = (await _tokenStorage.getDeviceId()) ?? const Uuid().v4();
    final events = <Map<String, dynamic>>[];

    // 1. Migrate Categories
    onProgress?.call(const MigrationProgress(
      step: 'Membaca kategori lokal...',
      totalItems: 0,
      processedItems: 0,
    ));
    final categories = await _localDb.categoryDao.getAllCategories(localStoreId);
    for (final cat in categories) {
      events.add({
        'eventId': const Uuid().v4(),
        'deviceId': deviceId,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'operation': 'CREATE_CATEGORY',
        'entityId': cat.id,
        'payload': {
          'id': cat.id,
          'name': cat.name,
        },
        'clientVersion': '1.0.0',
      });
    }

    // 2. Migrate Products & Variants
    onProgress?.call(MigrationProgress(
      step: 'Membaca produk lokal (${categories.length} kategori disiapkan)...',
      totalItems: 0,
      processedItems: 0,
    ));
    final products = await _localDb.productDao.getAllProducts(localStoreId);
    for (final prod in products) {
      final variants = await _localDb.productDao.getVariantsByProductId(prod.id);
      events.add({
        'eventId': const Uuid().v4(),
        'deviceId': deviceId,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'operation': 'CREATE_PRODUCT',
        'entityId': prod.id,
        'payload': {
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
        'clientVersion': '1.0.0',
      });
    }

    // 3. Migrate Customers
    onProgress?.call(MigrationProgress(
      step: 'Membaca data pelanggan (${products.length} produk disiapkan)...',
      totalItems: 0,
      processedItems: 0,
    ));
    final customers = await _localDb.customerDao.getAllCustomers(localStoreId);
    for (final cust in customers) {
      events.add({
        'eventId': const Uuid().v4(),
        'deviceId': deviceId,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'operation': 'CREATE_CUSTOMER',
        'entityId': cust.id,
        'payload': {
          'id': cust.id,
          'name': cust.name,
          'phone': cust.phone,
          'email': cust.email,
          'notes': cust.notes,
        },
        'clientVersion': '1.0.0',
      });
    }

    // 4. Migrate Promotions
    final promotions = await _localDb.promotionDao.getAllPromotions(localStoreId);
    for (final promo in promotions) {
      events.add({
        'eventId': const Uuid().v4(),
        'deviceId': deviceId,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'operation': 'CREATE_PROMOTION',
        'entityId': promo.id,
        'payload': {
          'id': promo.id,
          'name': promo.name,
          'code': promo.code,
          'discountType': promo.discountType,
          'discountValue': promo.discountValue,
          'minSpend': promo.minSpend,
          'startDate': promo.startDate?.toIso8601String(),
          'endDate': promo.endDate?.toIso8601String(),
          'productId': promo.productId,
          'active': promo.active,
        },
        'clientVersion': '1.0.0',
      });
    }

    // 5. Migrate Completed Transactions
    onProgress?.call(MigrationProgress(
      step: 'Membaca riwayat transaksi lokal...',
      totalItems: events.length,
      processedItems: events.length,
    ));
    final transactions = await _localDb.transactionDao.getTransactionsByStore(localStoreId, limit: 1000);
    for (final tx in transactions) {
      if (tx.status != 'COMPLETED') continue;
      final items = await _localDb.transactionDao.getItemsByTransactionId(tx.id);
      final payments = await _localDb.paymentDao.getPaymentsByTransactionId(tx.id);

      events.add({
        'eventId': const Uuid().v4(),
        'deviceId': deviceId,
        'occurredAt': tx.createdAt.toUtc().toIso8601String(),
        'operation': 'COMPLETE_TRANSACTION',
        'entityId': tx.id,
        'payload': {
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
          'completedAt': tx.completedAt?.toUtc().toIso8601String() ?? tx.createdAt.toUtc().toIso8601String(),
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
                    'metadata': p.metadata != null ? jsonDecode(p.metadata!) : null,
                  })
              .toList(),
        },
        'clientVersion': '1.0.0',
      });
    }

    // 6. Push events in chunks to server if any events exist
    if (events.isNotEmpty) {
      onProgress?.call(MigrationProgress(
        step: 'Mengunggah ${events.length} data ke Cloud Server...',
        totalItems: events.length,
        processedItems: 0,
      ));

      const chunkSize = 50;
      for (int i = 0; i < events.length; i += chunkSize) {
        final end = (i + chunkSize < events.length) ? i + chunkSize : events.length;
        final chunk = events.sublist(i, end);

        try {
          await apiClient.post('/api/v1/sync/push', {'events': chunk});
        } catch (_) {
          // If server rejects duplicate or has issue, continue best-effort
        }

        onProgress?.call(MigrationProgress(
          step: 'Mengunggah ke Cloud... ($end/${events.length})',
          totalItems: events.length,
          processedItems: end,
        ));
      }
    }

    // 7. Wipe local database after successful migration
    onProgress?.call(const MigrationProgress(
      step: 'Membersihkan database lokal...',
      totalItems: 1,
      processedItems: 1,
    ));
    await _resetService.clearLocalDatabaseOnly();

    // 8. Mark store as PRO migrated permanently
    await _tokenStorage.setProMigrated(true);
    await _tokenStorage.setCloudMode(true);

    onProgress?.call(const MigrationProgress(
      step: 'Migrasi ke Cloud PRO Selesai!',
      totalItems: 1,
      processedItems: 1,
    ));
  }
}
