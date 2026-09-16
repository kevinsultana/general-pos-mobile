import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/cloud_database.dart' hide SyncEvent, SyncEventsCompanion;
import 'package:mobile_pos/data/repositories/inventory_repository_impl.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';
import 'package:mobile_pos/domain/models/payment_input.dart';
import 'package:mobile_pos/data/services/cloud_sync_service.dart';
import 'package:mobile_pos/data/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


void main() {
  group('Phase 11 — Mode Switching & Cloud Hardening Tests', () {
    late AppDatabase localDb;
    late AppDatabase cloudDb;
    const storeId = 'store-hardening-01';
    const categoryId = 'cat-test-01';

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      localDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      cloudDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

      // Seed store and category in both databases
      for (final db in [localDb, cloudDb]) {
        await db.into(db.stores).insert(
              StoresCompanion.insert(
                id: storeId,
                name: 'Test Store',
                currency: const Value('IDR'),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        await db.into(db.categories).insert(
              CategoriesCompanion.insert(
                id: categoryId,
                storeId: storeId,
                name: 'Minuman & Makanan',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }
    });

    tearDown(() async {
      await localDb.close();
      await cloudDb.close();
    });

    // ──────────────── 1. Physical Dataset Isolation ────────────────

    test('Strict Dataset Isolation: local.sqlite and cloud_cache.sqlite never cross-pollinate', () async {
      // 1. Insert product into localDb
      final localProd = ProductsCompanion.insert(
        id: 'prod-local-001',
        storeId: storeId,
        categoryId: categoryId,
        name: 'Kopi Tubruk Lokal',
        cost: 3000,
        sellingPrice: 5000,
        stock: 50,
        lowStockThreshold: const Value(5),
        active: const Value(true),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.into(localDb.products).insert(localProd);

      // 2. Insert product into cloudDb
      final cloudProd = ProductsCompanion.insert(
        id: 'prod-cloud-001',
        storeId: storeId,
        categoryId: categoryId,
        name: 'Kopi Susu Gula Aren Cloud',
        cost: 8000,
        sellingPrice: 15000,
        stock: 100,
        lowStockThreshold: const Value(10),
        active: const Value(true),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await cloudDb.into(cloudDb.products).insert(cloudProd);

      // 3. Verify localDb only has local product
      final localProducts = await localDb.productDao.getAllProducts(storeId);
      expect(localProducts.length, 1);
      expect(localProducts.first.name, 'Kopi Tubruk Lokal');
      expect(localProducts.first.id, 'prod-local-001');

      // 4. Verify cloudDb only has cloud product
      final cloudProducts = await cloudDb.productDao.getAllProducts(storeId);
      expect(cloudProducts.length, 1);
      expect(cloudProducts.first.name, 'Kopi Susu Gula Aren Cloud');
      expect(cloudProducts.first.id, 'prod-cloud-001');
    });

    // ──────────────── 2. Offline Sync Event Enqueueing ────────────────

    test('Cloud Mode Transaction: Auto-enqueues COMPLETE_TRANSACTION to SyncEvents', () async {
      // Create product in cloudDb
      const prodId = 'prod-sync-001';
      await cloudDb.into(cloudDb.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              storeId: storeId,
              categoryId: categoryId,
              name: 'Ayam Geprek Cloud',
              cost: 10000,
              sellingPrice: 20000,
              stock: 30,
              lowStockThreshold: const Value(5),
              active: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Create transaction repository with isCloudMode: true
      final cloudTrxRepo = TransactionRepositoryImpl(
        cloudDb,
        null,
        true, // isCloudMode
        'test-device-pos',
      );

      const cartItem = CartItem(
        productId: prodId,
        productName: 'Ayam Geprek Cloud',
        unitPrice: 20000,
        quantity: 2,
        unitCostSnapshot: 10000,
      );

      final payment = PaymentInput(
        paymentMethodId: 'cash-method',
        amount: 40000,
        roundingAmount: 0,
        paymentType: 'CASH',
        tenderedAmount: 50000,
        changeAmount: 10000,
      );

      // Complete transaction offline
      final trxId = await cloudTrxRepo.completeTransaction(
        storeId: storeId,
        orderType: 'DINE_IN',
        subtotal: 40000,
        discountTotal: 0,
        roundingAmount: 0,
        total: 40000,
        items: [cartItem],
        payments: [payment],
      );

      expect(trxId, isNotEmpty);

      // Verify stock was deducted locally
      final updatedProd = await cloudDb.productDao.getProductById(prodId);
      expect(updatedProd?.stock, 28); // 30 - 2

      // Verify SyncEvent was automatically enqueued in cloudDb.syncEvents
      final pendingEvents = await cloudDb.syncEventDao.getPendingEvents(storeId);
      expect(pendingEvents.length, 1);

      final event = pendingEvents.first;
      expect(event.operation, 'COMPLETE_TRANSACTION');
      expect(event.entityType, 'Transaction');
      expect(event.entityId, trxId);
      expect(event.status, 'PENDING');
      expect(event.deviceId, 'test-device-pos');
      expect(event.payload, contains('Ayam Geprek Cloud'));
      expect(event.payload, contains('40000'));
    });

    // ──────────────── 3. Offline Cancellation Sync Event ────────────────

    test('Cloud Mode Cancel: Auto-enqueues CANCEL_TRANSACTION and reverses stock', () async {
      const prodId = 'prod-sync-cancel';
      await cloudDb.into(cloudDb.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              storeId: storeId,
              categoryId: categoryId,
              name: 'Es Teh Manis',
              cost: 1500,
              sellingPrice: 5000,
              stock: 20,
              lowStockThreshold: const Value(5),
              active: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final cloudTrxRepo = TransactionRepositoryImpl(
        cloudDb,
        null,
        true, // isCloudMode
        'test-device-pos',
      );

      final trxId = await cloudTrxRepo.completeTransaction(
        storeId: storeId,
        orderType: 'TAKEAWAY',
        subtotal: 5000,
        discountTotal: 0,
        roundingAmount: 0,
        total: 5000,
        items: [
          const CartItem(
            productId: prodId,
            productName: 'Es Teh Manis',
            unitPrice: 5000,
            quantity: 1,
            unitCostSnapshot: 1500,
          ),
        ],
        payments: [
          PaymentInput(
            paymentMethodId: 'cash-method',
            amount: 5000,
            roundingAmount: 0,
            paymentType: 'CASH',
            tenderedAmount: 5000,
            changeAmount: 0,
          ),
        ],
      );

      // Cancel transaction
      await cloudTrxRepo.cancelTransaction(
        transactionId: trxId,
        reason: 'Customer cancelled order',
      );

      // Stock should be restored
      final restoredProd = await cloudDb.productDao.getProductById(prodId);
      expect(restoredProd?.stock, 20);

      // Verify CANCEL_TRANSACTION is enqueued
      final pendingEvents = await cloudDb.syncEventDao.getPendingEvents(storeId);
      expect(pendingEvents.length, 2); // COMPLETE_TRANSACTION + CANCEL_TRANSACTION

      final cancelEvent = pendingEvents.last;
      expect(cancelEvent.operation, 'CANCEL_TRANSACTION');
      expect(cancelEvent.entityId, trxId);
      expect(cancelEvent.status, 'PENDING');
      expect(cancelEvent.payload, contains('Customer cancelled order'));
    });

    // ──────────────── 4. Offline Stock Adjustment Sync Event ────────────────

    test('Cloud Mode Stock Adjustment: Auto-enqueues ADJUST_STOCK event', () async {
      const prodId = 'prod-adjust-001';
      await cloudDb.into(cloudDb.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              storeId: storeId,
              categoryId: categoryId,
              name: 'Kopi Arabika Bean',
              cost: 50000,
              sellingPrice: 85000,
              stock: 10,
              lowStockThreshold: const Value(2),
              active: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final invRepo = InventoryRepositoryImpl(
        cloudDb,
        cloudDb.productDao,
        cloudDb.stockMovementDao,
        null,
        true, // isCloudMode
        'test-device-pos',
      );

      await invRepo.stockAdjustment(
        storeId: storeId,
        productId: prodId,
        deltaQty: 5,
        reason: 'Restock batch from central warehouse',
      );

      final updatedProd = await cloudDb.productDao.getProductById(prodId);
      expect(updatedProd?.stock, 15);

      final pendingEvents = await cloudDb.syncEventDao.getPendingEvents(storeId);
      expect(pendingEvents.length, 1);
      expect(pendingEvents.first.operation, 'ADJUST_STOCK');
      expect(pendingEvents.first.entityType, 'StockMovement');
      expect(pendingEvents.first.payload, contains('Restock batch from central warehouse'));
    });

    // ──────────────── 5. Inbound Sync Dispatching ────────────────

    test('Inbound Sync: Remote ADJUST_STOCK updates local stock and records movement', () async {
      const prodId = 'prod-inbound-01';
      await cloudDb.into(cloudDb.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              storeId: storeId,
              categoryId: categoryId,
              name: 'Teh Hijau Inbound',
              cost: 5000,
              sellingPrice: 10000,
              stock: 20,
              lowStockThreshold: const Value(3),
              active: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final tokenStorage = TokenStorage(const FlutterSecureStorage());
      final apiClient = ApiClient(tokenStorage);
      final cloudSyncDb = CloudDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      final syncService = CloudSyncService(
        cloudSyncDb.cloudSyncEventDao,
        apiClient,
        tokenStorage,
        cloudDb,
      );

      // Simulate inbound ADJUST_STOCK pulled from server
      await syncService.dispatchOperationForTesting(
        storeId,
        'ADJUST_STOCK',
        {
          'productId': prodId,
          'quantityDelta': -5,
          'reason': 'Damaged in warehouse',
        },
      );

      final updated = await cloudDb.productDao.getProductById(prodId);
      expect(updated?.stock, 15);

      final movements = await cloudDb.stockMovementDao.getMovementsByProduct(prodId);
      expect(movements.length, 1);
      expect(movements.first.type, 'ADJUSTMENT');
      expect(movements.first.reason, 'Damaged in warehouse');
      await cloudSyncDb.close();
    });

    // ──────────────── 6. Partial Refund ────────────────

    test('Partial Refund: Refunding 1 of 2 items sets status to PARTIALLY_REFUNDED and restores only 1 unit stock', () async {
      const prodId = 'prod-partial-01';
      await cloudDb.into(cloudDb.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              storeId: storeId,
              categoryId: categoryId,
              name: 'Coklat Panas',
              cost: 7000,
              sellingPrice: 15000,
              stock: 10,
              lowStockThreshold: const Value(2),
              active: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final trxRepo = TransactionRepositoryImpl(cloudDb, null, false);
      const cartItem = CartItem(
        productId: prodId,
        productName: 'Coklat Panas',
        unitPrice: 15000,
        quantity: 2,
        unitCostSnapshot: 7000,
      );

      final payment = PaymentInput(
        paymentMethodId: 'cash-method',
        amount: 30000,
        roundingAmount: 0,
        paymentType: 'CASH',
        tenderedAmount: 30000,
        changeAmount: 0,
      );

      final trxId = await trxRepo.completeTransaction(
        storeId: storeId,
        orderType: 'DINE_IN',
        subtotal: 30000,
        discountTotal: 0,
        roundingAmount: 0,
        total: 30000,
        items: [cartItem],
        payments: [payment],
      );

      // Stock reduced to 8
      var prod = await cloudDb.productDao.getProductById(prodId);
      expect(prod?.stock, 8);

      final items = await trxRepo.getTransactionItems(trxId);
      expect(items.length, 1);
      expect(items.first.quantity, 2);

      // Partial refund: refund only 1 unit out of 2
      await trxRepo.refundTransaction(
        transactionId: trxId,
        reason: 'Customer only wanted 1 cup',
        items: [
          RefundItemInput(
            transactionItemId: items.first.id,
            productId: prodId,
            quantity: 1,
            refundAmount: 15000,
          ),
        ],
        totalRefundAmount: 15000,
      );

      // Stock should be 9 (only 1 unit restored)
      prod = await cloudDb.productDao.getProductById(prodId);
      expect(prod?.stock, 9);

      // Status should be PARTIALLY_REFUNDED and refundedAt should be recorded
      final updatedTrx = await trxRepo.getTransaction(trxId);
      expect(updatedTrx?.status, 'PARTIALLY_REFUNDED');
      expect(updatedTrx?.refundedAt, isNotNull);
    });

    // ──────────────── 7. Inbound Sync Refund ────────────────

    test('Inbound Sync: Remote REFUND_TRANSACTION updates status, sets refundedAt, and restores stock', () async {
      const prodId = 'prod-inbound-refund';
      await cloudDb.into(cloudDb.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              storeId: storeId,
              categoryId: categoryId,
              name: 'Matcha Latte Inbound',
              cost: 6000,
              sellingPrice: 18000,
              stock: 10,
              lowStockThreshold: const Value(2),
              active: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      const trxId = 'trx-inbound-refund-01';
      await cloudDb.into(cloudDb.transactions).insert(
            TransactionsCompanion.insert(
              id: trxId,
              storeId: storeId,
              transactionNumber: 'TRX-REFUND-001',
              status: 'COMPLETED',
              subtotal: 18000,
              total: 18000,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final tokenStorage = TokenStorage(const FlutterSecureStorage());
      final apiClient = ApiClient(tokenStorage);
      final cloudSyncDb = CloudDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      final syncService = CloudSyncService(
        cloudSyncDb.cloudSyncEventDao,
        apiClient,
        tokenStorage,
        cloudDb,
      );

      final refundDate = DateTime(2026, 9, 16, 12, 0);
      await syncService.dispatchOperationForTesting(
        storeId,
        'REFUND_TRANSACTION',
        {
          'transactionId': trxId,
          'status': 'REFUNDED',
          'isFullRefund': true,
          'refundedAt': refundDate.toIso8601String(),
          'reason': 'Remote refund from dashboard',
          'items': [
            {'productId': prodId, 'quantity': 1},
          ],
        },
      );

      final updatedTrx = await cloudDb.transactionDao.getTransactionById(trxId);
      expect(updatedTrx?.status, 'REFUNDED');
      expect(updatedTrx?.refundedAt, isNotNull);

      final prod = await cloudDb.productDao.getProductById(prodId);
      expect(prod?.stock, 11); // 10 + 1 restored

      await cloudSyncDb.close();
    });
  });
}
