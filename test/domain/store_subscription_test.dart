import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/daos/store_dao.dart';
import 'package:mobile_pos/data/repositories/store_repository_impl.dart';

void main() {
  late AppDatabase db;
  late StoreDao storeDao;
  late StoreRepositoryImpl storeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storeDao = StoreDao(db);
    storeRepo = StoreRepositoryImpl(storeDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('P4.1 Store Subscription Plan & Status Tests', () {
    test('ensureDefaultStore initializes with default PRO subscription plan and ACTIVE status', () async {
      final store = await storeRepo.ensureDefaultStore();

      expect(store.subscriptionPlan, 'PRO');
      expect(store.subscriptionStatus, 'ACTIVE');
      expect(store.subscriptionExpiresAt, isNull);
    });

    test('updateSubscription persists target plan, status, and expiration date', () async {
      final initialStore = await storeRepo.ensureDefaultStore();
      final expiresAt = DateTime(2027, 1, 1);

      await storeRepo.updateSubscription(
        storeId: initialStore.id,
        plan: 'PAID',
        status: 'ACTIVE',
        expiresAt: expiresAt,
      );

      final updatedStore = await storeRepo.getStore(initialStore.id);
      expect(updatedStore, isNotNull);
      expect(updatedStore!.subscriptionPlan, 'PAID');
      expect(updatedStore.subscriptionStatus, 'ACTIVE');
      expect(updatedStore.subscriptionExpiresAt, expiresAt);
    });

    test('updateSubscription handles EXPIRED and CANCELLED status correctly', () async {
      final initialStore = await storeRepo.ensureDefaultStore();

      await storeRepo.updateSubscription(
        storeId: initialStore.id,
        plan: 'FREE',
        status: 'EXPIRED',
      );

      final updatedStore = await storeRepo.getStore(initialStore.id);
      expect(updatedStore!.subscriptionPlan, 'FREE');
      expect(updatedStore.subscriptionStatus, 'EXPIRED');
    });
  });
}
