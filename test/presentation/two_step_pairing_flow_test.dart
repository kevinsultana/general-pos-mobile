import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/services/api_client.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/daos/store_dao.dart';
import 'package:mobile_pos/data/repositories/store_repository_impl.dart';
import 'package:drift/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Two-Step Device Pairing & Cashier Session Tests', () {
    late TokenStorage tokenStorage;
    late AppDatabase db;
    late StoreDao storeDao;
    late StoreRepositoryImpl storeRepo;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      tokenStorage = TokenStorage(const FlutterSecureStorage());
      db = AppDatabase.forTesting(NativeDatabase.memory());
      storeDao = StoreDao(db);
      storeRepo = StoreRepositoryImpl(storeDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('TokenStorage manages store pairing and cashier session lifecycle', () async {
      // 1. Initial state: not paired, no cashier
      expect(await tokenStorage.isStorePaired(), false);
      expect(await tokenStorage.getCashierUserId(), isNull);

      // 2. Pair store
      await tokenStorage.setStorePaired(true);
      await tokenStorage.saveTokens(
        accessToken: 'mock-access',
        refreshToken: 'mock-refresh',
        storeId: 'store-pro-1',
        userId: 'owner-1',
      );
      await tokenStorage.saveTier(tier: 'PRO', canCloudSync: true);
      expect(await tokenStorage.isStorePaired(), true);
      expect(await tokenStorage.getStoreId(), 'store-pro-1');

      // 3. Save cashier session
      await tokenStorage.saveCashierSession(
        userId: 'cashier-101',
        username: 'budi_kasir',
        displayName: 'Budi Kasir',
        role: 'CASHIER',
        permissions: ['create_transaction', 'view_sales'],
      );

      expect(await tokenStorage.getCashierUserId(), 'cashier-101');
      expect(await tokenStorage.getCashierUsername(), 'budi_kasir');
      expect(await tokenStorage.getCashierDisplayName(), 'Budi Kasir');
      expect(await tokenStorage.getCashierRole(), 'CASHIER');
      expect(await tokenStorage.getCashierPermissions(), ['create_transaction', 'view_sales']);

      // 4. "Ganti Kasir" clears cashier session without unpairing store
      await tokenStorage.clearCashierSession();
      expect(await tokenStorage.getCashierUserId(), isNull);
      expect(await tokenStorage.isStorePaired(), true);
      expect(await tokenStorage.getStoreId(), 'store-pro-1');
      expect(await tokenStorage.getTier(), 'PRO');

      // 5. "Putus Perangkat (Unpair)" clears everything
      await tokenStorage.clearAll();
      expect(await tokenStorage.isStorePaired(), false);
      expect(await tokenStorage.getStoreId(), isNull);
      expect(await tokenStorage.getCashierUserId(), isNull);
    });

    test('Step 1 Free Tier: Stores Owner in Users, auto-bypasses staff login, heals orphan records', () async {
      const freeStoreId = 'store-free-001';
      const ownerUserId = 'owner-free-001';

      // Simulate Owner provisioning a FREE store
      await storeRepo.bindCloudStoreAndUser(
        storeId: freeStoreId,
        storeName: 'Warung Kopi Jaya',
        subscriptionPlan: 'FREE',
        userId: ownerUserId,
        username: 'owner_kopi',
        displayName: 'Pak Joko (Owner)',
      );

      // Verify Store saved in Drift Stores
      final store = await storeRepo.getStore(freeStoreId);
      expect(store, isNotNull);
      expect(store!.name, 'Warung Kopi Jaya');
      expect(store.subscriptionPlan, 'FREE');

      // Verify Owner saved in Drift Users table
      final adminUser = await storeRepo.getAdminUser(freeStoreId);
      expect(adminUser, isNotNull);
      expect(adminUser!.id, ownerUserId);
      expect(adminUser.username, 'owner_kopi');
      expect(adminUser.role, 'ADMIN');

      // Verify TokenStorage setup for Free tier single-user
      await tokenStorage.setStorePaired(true);
      await tokenStorage.saveTokens(
        accessToken: 'free-token',
        refreshToken: 'free-refresh',
        storeId: freeStoreId,
        userId: ownerUserId,
      );
      await tokenStorage.saveTier(tier: 'FREE', canCloudSync: false);
      await tokenStorage.setCloudMode(false);
      await tokenStorage.saveCashierSession(
        userId: ownerUserId,
        username: 'owner_kopi',
        displayName: 'Pak Joko (Owner)',
        role: 'OWNER',
        permissions: ['*'],
      );

      expect(await tokenStorage.isStorePaired(), true);
      expect(await tokenStorage.isCloudMode(), false);
      expect(await tokenStorage.getCashierUserId(), ownerUserId);
    });

    test('Step 1 Pro Tier: Pairs store and leaves cashier session empty for Step 2 Staff Login', () async {
      const proStoreId = 'store-pro-002';
      const ownerUserId = 'owner-pro-002';

      await storeRepo.bindCloudStoreAndUser(
        storeId: proStoreId,
        storeName: 'Resto Mega Rasa',
        subscriptionPlan: 'PRO',
        userId: ownerUserId,
        username: 'owner_mega',
        displayName: 'Bu Siti (Owner)',
      );

      await tokenStorage.setStorePaired(true);
      await tokenStorage.saveTokens(
        accessToken: 'pro-token',
        refreshToken: 'pro-refresh',
        storeId: proStoreId,
        userId: ownerUserId,
      );
      await tokenStorage.saveTier(tier: 'PRO', canCloudSync: true);

      // Cashier session is still empty -> requires /staff-login
      expect(await tokenStorage.isStorePaired(), true);
      expect(await tokenStorage.getCashierUserId(), isNull);
    });
  });
}
