import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/cloud_database.dart';
import 'package:mobile_pos/data/services/api_client.dart';
import 'package:mobile_pos/data/services/cloud_sync_service.dart';

void main() {
  group('P3.1 SyncEvent Operations & Inbound Dispatch Tests', () {
    late AppDatabase db;
    late CloudDatabase cloudDb;
    late CloudSyncService syncService;

    const storeId = 'store-test-p31';

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      cloudDb = CloudDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      final tokenStorage = TokenStorage(const FlutterSecureStorage());
      final apiClient = ApiClient(tokenStorage);

      syncService = CloudSyncService(
        cloudDb.cloudSyncEventDao,
        apiClient,
        tokenStorage,
        db,
      );
    });

    tearDown(() async {
      await db.close();
      await cloudDb.close();
    });

    test('entityTypeFor maps all operations to correct entity types', () {
      expect(syncService.entityTypeFor('COMPLETE_TRANSACTION'), equals('Transaction'));
      expect(syncService.entityTypeFor('CANCEL_TRANSACTION'), equals('Transaction'));
      expect(syncService.entityTypeFor('REFUND_TRANSACTION'), equals('Transaction'));
      expect(syncService.entityTypeFor('ADJUST_STOCK'), equals('StockMovement'));

      expect(syncService.entityTypeFor('CREATE_CATEGORY'), equals('Category'));
      expect(syncService.entityTypeFor('UPDATE_CATEGORY'), equals('Category'));
      expect(syncService.entityTypeFor('DELETE_CATEGORY'), equals('Category'));

      expect(syncService.entityTypeFor('CREATE_PRODUCT'), equals('Product'));
      expect(syncService.entityTypeFor('UPDATE_PRODUCT'), equals('Product'));
      expect(syncService.entityTypeFor('DELETE_PRODUCT'), equals('Product'));

      expect(syncService.entityTypeFor('CREATE_CUSTOMER'), equals('Customer'));
      expect(syncService.entityTypeFor('UPDATE_CUSTOMER'), equals('Customer'));
      expect(syncService.entityTypeFor('DELETE_CUSTOMER'), equals('Customer'));

      expect(syncService.entityTypeFor('CREATE_PROMOTION'), equals('Promotion'));
      expect(syncService.entityTypeFor('UPDATE_PROMOTION'), equals('Promotion'));
      expect(syncService.entityTypeFor('DELETE_PROMOTION'), equals('Promotion'));

      expect(syncService.entityTypeFor('SOMETHING_ELSE'), equals('Unknown'));
    });

    test('Inbound dispatch: CREATE_PRODUCT and DELETE_PRODUCT', () async {
      const prodId = 'prod-sync-01';

      // 1. CREATE_PRODUCT
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_PRODUCT',
        {
          'id': prodId,
          'name': 'Kopi Latte Sync',
          'categoryId': 'cat-beverages',
          'sellingPrice': 25000,
          'cost': 12000,
          'stock': 40,
          'sku': 'LATTE-01',
        },
      );

      final created = await db.productDao.getProductById(prodId);
      expect(created, isNotNull);
      expect(created!.name, equals('Kopi Latte Sync'));
      expect(created.sellingPrice, equals(25000));

      // 2. DELETE_PRODUCT
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE_PRODUCT',
        {'id': prodId},
      );

      final deleted = await db.productDao.getProductById(prodId);
      expect(deleted, isNull);
    });

    test('Inbound dispatch: CREATE_CUSTOMER and DELETE_CUSTOMER', () async {
      const custId = 'cust-sync-01';

      // 1. CREATE_CUSTOMER
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_CUSTOMER',
        {
          'id': custId,
          'name': 'John Doe',
          'phone': '08123456789',
          'email': 'john@example.com',
          'notes': 'Regular Customer',
        },
      );

      final created = await db.customerDao.getCustomerById(custId);
      expect(created, isNotNull);
      expect(created!.name, equals('John Doe'));
      expect(created.phone, equals('08123456789'));

      // 2. DELETE_CUSTOMER
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE_CUSTOMER',
        {'id': custId},
      );

      final deleted = await db.customerDao.getCustomerById(custId);
      expect(deleted, isNull);
    });

    test('Inbound dispatch: CREATE_PROMOTION and DELETE_PROMOTION', () async {
      const promoId = 'promo-sync-01';

      // 1. CREATE_PROMOTION
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_PROMOTION',
        {
          'id': promoId,
          'name': 'Diskon Grand Opening',
          'code': 'OPENING10',
          'discountType': 'PERCENTAGE',
          'discountValue': 10,
          'minSpend': 30000,
          'active': true,
        },
      );

      final created = await db.promotionDao.getPromotionById(promoId);
      expect(created, isNotNull);
      expect(created!.name, equals('Diskon Grand Opening'));
      expect(created.discountValue, equals(10));
      expect(created.minSpend, equals(30000));

      // 2. DELETE_PROMOTION
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE_PROMOTION',
        {'id': promoId},
      );

      final deleted = await db.promotionDao.getPromotionById(promoId);
      expect(deleted, isNull);
    });

    test('Inbound dispatch: generic DELETE with entityType', () async {
      const prodId = 'prod-generic-del';
      const custId = 'cust-generic-del';
      const promoId = 'promo-generic-del';

      // Seed product, customer, promotion
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_PRODUCT',
        {'id': prodId, 'name': 'Item X', 'categoryId': 'cat-1'},
      );
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_CUSTOMER',
        {'id': custId, 'name': 'Jane X'},
      );
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_PROMOTION',
        {'id': promoId, 'name': 'Promo X'},
      );

      expect(await db.productDao.getProductById(prodId), isNotNull);
      expect(await db.customerDao.getCustomerById(custId), isNotNull);
      expect(await db.promotionDao.getPromotionById(promoId), isNotNull);

      // Generic DELETE for Product
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE',
        {'entityType': 'Product', 'id': prodId},
      );
      expect(await db.productDao.getProductById(prodId), isNull);

      // Generic DELETE for Customer
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE',
        {'entityType': 'Customer', 'id': custId},
      );
      expect(await db.customerDao.getCustomerById(custId), isNull);

      // Generic DELETE for Promotion
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE',
        {'entityType': 'Promotion', 'id': promoId},
      );
      expect(await db.promotionDao.getPromotionById(promoId), isNull);
    });

    test('Inbound dispatch: CREATE_CATEGORY and DELETE_CATEGORY', () async {
      const catId = 'cat-test-01';

      // 1. CREATE_CATEGORY
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_CATEGORY',
        {
          'id': catId,
          'name': 'Makanan Ringan',
        },
      );

      final cat = await db.categoryDao.getCategoryById(catId);
      expect(cat, isNotNull);
      expect(cat!.name, equals('Makanan Ringan'));

      // 2. DELETE_CATEGORY
      await syncService.dispatchOperationForTesting(
        storeId,
        'DELETE_CATEGORY',
        {'id': catId},
      );

      final deleted = await db.categoryDao.getCategoryById(catId);
      expect(deleted, isNull);
    });

    test('Inbound dispatch: CREATE_PRODUCT with nested variants and ADJUST_STOCK on variant', () async {
      const prodId = 'prod-var-01';
      const variantId = 'var-01';

      // 1. CREATE_PRODUCT with variants
      await syncService.dispatchOperationForTesting(
        storeId,
        'CREATE_PRODUCT',
        {
          'id': prodId,
          'name': 'Kemeja Formal',
          'categoryId': 'cat-apparel',
          'sellingPrice': 150000,
          'cost': 100000,
          'stock': 20,
          'variants': [
            {
              'id': variantId,
              'name': 'Ukuran XL',
              'sellingPrice': 160000,
              'cost': 105000,
              'stock': 10,
            }
          ],
        },
      );

      final prod = await db.productDao.getProductById(prodId);
      expect(prod, isNotNull);
      expect(prod!.stock, equals(20));

      final variants = await db.productDao.getVariantsByProductId(prodId);
      expect(variants.length, equals(1));
      expect(variants.first.id, equals(variantId));
      expect(variants.first.stock, equals(10));

      // 2. ADJUST_STOCK with variantId
      await syncService.dispatchOperationForTesting(
        storeId,
        'ADJUST_STOCK',
        {
          'productId': prodId,
          'variantId': variantId,
          'quantityDelta': -3,
          'reason': 'Damaged item',
        },
      );

      final updatedProd = await db.productDao.getProductById(prodId);
      expect(updatedProd!.stock, equals(17)); // 20 - 3

      final updatedVariants = await db.productDao.getVariantsByProductId(prodId);
      expect(updatedVariants.first.stock, equals(7)); // 10 - 3
    });
  });
}
