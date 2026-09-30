import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/services/api_client.dart';
import 'package:mobile_pos/data/services/data_migration_service.dart';

class MockApiClient extends ApiClient {
  final List<Map<String, dynamic>> pushPayloads = [];

  MockApiClient(super.tokenStorage);

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    if (path == '/sync/push') {
      pushPayloads.add(body);
      final events = body['events'] as List<dynamic>? ?? [];
      return {
        'success': true,
        'data': {
          'processed': events.length,
          'errors': [],
        },
      };
    }
    return {'success': true, 'data': {}};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataMigrationService - migrateAndPushLocalDataToCloud Tests', () {
    late AppDatabase localDb;
    late AppDatabase cloudDb;
    late TokenStorage tokenStorage;
    late MockApiClient mockApiClient;
    late DataMigrationService migrationService;

    const testStoreId = 'store-mig-test-001';
    const testCatId = 'cat-mig-001';
    const testProdId = 'prod-mig-001';
    const testCustId = 'cust-mig-001';
    const testPromoId = 'promo-mig-001';
    const testTxId = 'tx-mig-001';
    const testSmId = 'sm-mig-001';

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      tokenStorage = TokenStorage(const FlutterSecureStorage());
      mockApiClient = MockApiClient(tokenStorage);

      localDb = AppDatabase.forTesting(drift.DatabaseConnection(NativeDatabase.memory()));
      cloudDb = AppDatabase.forTesting(drift.DatabaseConnection(NativeDatabase.memory()));

      migrationService = DataMigrationService(
        localDb: localDb,
        cloudDb: cloudDb,
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
      );

      // Seed Store in both databases
      for (final db in [localDb, cloudDb]) {
        await db.into(db.stores).insert(
              StoresCompanion.insert(
                id: testStoreId,
                name: 'Toko Offline Serba Ada',
                subscriptionPlan: const drift.Value('FREE'),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }

      // Seed offline local entities in localDb
      // 1. Category
      await localDb.categoryDao.insertCategory(
        CategoriesCompanion.insert(
          id: testCatId,
          storeId: testStoreId,
          name: 'Makanan Ringan',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Product
      await localDb.productDao.insertProduct(
        ProductsCompanion.insert(
          id: testProdId,
          storeId: testStoreId,
          categoryId: testCatId,
          name: 'Keripik Singkong Balado',
          sku: const drift.Value('KRP-BLD-01'),
          cost: 5000,
          sellingPrice: 10000,
          stock: 25,
          lowStockThreshold: const drift.Value(5),
          active: const drift.Value(true),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 3. Customer
      await localDb.customerDao.insertCustomer(
        CustomersCompanion.insert(
          id: testCustId,
          storeId: testStoreId,
          name: 'Pak Budi Santoso',
          phone: const drift.Value('081234567890'),
          email: const drift.Value('budi@example.com'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 4. Promotion
      await localDb.promotionDao.insertPromotion(
        PromotionsCompanion.insert(
          id: testPromoId,
          storeId: testStoreId,
          name: 'Diskon Kemerdekaan',
          type: 'PERCENTAGE',
          scope: 'STOREWIDE',
          discountValue: 17,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          active: const drift.Value(true),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 5. Completed Transaction
      final txTime = DateTime(2026, 8, 17, 10, 30);
      await localDb.transactionDao.insertTransaction(
        TransactionsCompanion.insert(
          id: testTxId,
          storeId: testStoreId,
          transactionNumber: 'TRX-OFFLINE-001',
          customerId: const drift.Value(testCustId),
          orderType: const drift.Value('TAKEAWAY'),
          subtotal: 20000,
          discountTotal: 0,
          roundingAmount: const drift.Value(0),
          total: 20000,
          paidTotal: 20000,
          changeTotal: 0,
          status: 'COMPLETED',
          completedAt: drift.Value(txTime),
          createdAt: txTime,
          updatedAt: txTime,
        ),
      );

      await localDb.transactionDao.insertTransactionItem(
        TransactionItemsCompanion.insert(
          id: 'item-mig-001',
          transactionId: testTxId,
          productId: testProdId,
          productNameSnapshot: 'Keripik Singkong Balado',
          unitCostSnapshot: 5000,
          quantity: 2,
          unitPrice: 10000,
          subtotal: 20000,
          total: 20000,
          createdAt: txTime,
          updatedAt: txTime,
        ),
      );

      await localDb.paymentDao.insertPayment(
        PaymentsCompanion.insert(
          id: 'pay-mig-001',
          transactionId: testTxId,
          paymentMethodId: 'cash-pm-01',
          amount: 20000,
          status: 'COMPLETED',
          paidAt: drift.Value(txTime),
          createdAt: txTime,
          updatedAt: txTime,
        ),
      );

      // 6. Stock Movement
      await localDb.stockMovementDao.recordMovement(
        StockMovementsCompanion.insert(
          id: drift.Value(testSmId),
          storeId: const drift.Value(testStoreId),
          productId: const drift.Value(testProdId),
          type: const drift.Value('STOCK_IN'),
          quantityDelta: const drift.Value(25),
          unitCost: const drift.Value(5000),
          reason: const drift.Value('Stok awal toko offline'),
          createdAt: drift.Value(DateTime(2026, 8, 1, 9, 0)),
        ),
      );
    });

    tearDown(() async {
      await localDb.close();
      await cloudDb.close();
    });

    test('migrateAndPushLocalDataToCloud pushes all entities and populates cloud_cache.sqlite', () async {
      final progressSteps = <String>[];

      await migrationService.migrateAndPushLocalDataToCloud(
        testStoreId,
        onProgress: (p) => progressSteps.add(p.step),
      );

      // 1. Verify sync push was performed
      expect(mockApiClient.pushPayloads.isNotEmpty, true);
      final allEvents = <Map<String, dynamic>>[];
      for (final payload in mockApiClient.pushPayloads) {
        final events = payload['events'] as List<dynamic>;
        allEvents.addAll(events.cast<Map<String, dynamic>>());
      }

      // Check operations in pushed events
      final operations = allEvents.map((e) => e['operation']).toSet();
      expect(operations.contains('CREATE_CATEGORY'), true);
      expect(operations.contains('CREATE_PRODUCT'), true);
      expect(operations.contains('CREATE_CUSTOMER'), true);
      expect(operations.contains('CREATE_PROMOTION'), true);
      expect(operations.contains('COMPLETE_TRANSACTION'), true);
      expect(operations.contains('ADJUST_STOCK'), true);

      // Verify transaction preservation
      final txEvent = allEvents.firstWhere((e) => e['operation'] == 'COMPLETE_TRANSACTION');
      expect(txEvent['entityId'], testTxId);
      final txPayload = txEvent['payload'] as Map<String, dynamic>;
      expect(txPayload['transactionNumber'], 'TRX-OFFLINE-001');
      expect(txPayload['completedAt'], isNotNull);
      expect(txPayload['createdAt'], isNotNull);

      // 2. Verify all entities copied into cloudDb (cloud_cache.sqlite)
      final cloudCategories = await cloudDb.categoryDao.getAllCategories(testStoreId);
      expect(cloudCategories.any((c) => c.id == testCatId), true);

      final cloudProducts = await cloudDb.productDao.getAllProducts(testStoreId);
      expect(cloudProducts.any((p) => p.id == testProdId), true);

      final cloudCustomers = await cloudDb.customerDao.getAllCustomers(testStoreId);
      expect(cloudCustomers.any((c) => c.id == testCustId), true);

      final cloudPromotions = await cloudDb.promotionDao.getAllPromotions(testStoreId);
      expect(cloudPromotions.any((p) => p.id == testPromoId), true);

      final cloudTx = await cloudDb.transactionDao.getTransactionById(testTxId);
      expect(cloudTx, isNotNull);
      expect(cloudTx!.transactionNumber, 'TRX-OFFLINE-001');

      final cloudItems = await cloudDb.transactionDao.getItemsByTransactionId(testTxId);
      expect(cloudItems.length, 1);
      expect(cloudItems.first.productId, testProdId);

      final cloudPayments = await cloudDb.paymentDao.getPaymentsByTransactionId(testTxId);
      expect(cloudPayments.length, 1);
      expect(cloudPayments.first.amount, 20000);

      // 3. Verify TokenStorage updated flags
      expect(await tokenStorage.isProMigrated(), true);
      expect(await tokenStorage.isCloudMode(), true);
      expect(await tokenStorage.getTier(), 'PRO');
      expect(await tokenStorage.canCloudSync(), true);

      // 4. Verify progress callbacks were executed
      expect(progressSteps.contains('Migrasi ke Cloud PRO Selesai!'), true);
    });
  });
}
