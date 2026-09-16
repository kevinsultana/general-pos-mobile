import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/store_tables.dart';

part 'store_dao.g.dart';

@DriftAccessor(tables: [Stores])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  Future<Store?> getStoreById(String id) {
    return (select(stores)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<Store?> watchStoreById(String id) {
    return (select(stores)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  Future<Store?> getFirstStore() {
    return (select(stores)..limit(1)).getSingleOrNull();
  }

  Stream<Store?> watchFirstStore() {
    return (select(stores)..limit(1)).watchSingleOrNull();
  }

  Future<Store> ensureDefaultStore() async {
    try {
      final existing = await getFirstStore();
      if (existing != null) return existing;
    } catch (_) {
      try {
        await customStatement("UPDATE \"stores\" SET \"subscription_plan\" = 'PRO' WHERE \"subscription_plan\" IS NULL;");
        await customStatement("UPDATE \"stores\" SET \"subscription_status\" = 'ACTIVE' WHERE \"subscription_status\" IS NULL;");
        final healed = await getFirstStore();
        if (healed != null) return healed;
      } catch (_) {}
    }

    final now = DateTime.now();
    final defaultStore = StoresCompanion.insert(
      id: 'store-default-01',
      name: 'Toko UMKM POS',
      ownerName: const Value('Owner'),
      currency: const Value('IDR'),
      timezone: const Value('Asia/Jakarta'),
      language: const Value('id'),
      businessType: const Value('GENERAL'),
      customerEnabled: const Value(false),
      draftEnabled: const Value(true),
      splitPaymentEnabled: const Value(true),
      refundEnabled: const Value(true),
      cashRoundingEnabled: const Value(true),
      cashRoundingIncrement: const Value(100),
      cashRoundingMode: const Value('ROUND_NEAREST'),
      subscriptionPlan: const Value('PRO'),
      subscriptionStatus: const Value('ACTIVE'),
      subscriptionExpiresAt: const Value(null),
      createdAt: now,
      updatedAt: now,
    );
    await insertStore(defaultStore);
    return (await getStoreById('store-default-01'))!;
  }

  Future<void> insertStore(StoresCompanion store) {
    return into(stores).insert(store, mode: InsertMode.insertOrReplace);
  }

  Future<bool> updateStore(StoresCompanion store) {
    return update(stores).replace(store);
  }

  Future<void> setCustomerEnabled(String storeId, bool enabled) {
    return (update(stores)..where((tbl) => tbl.id.equals(storeId))).write(
      StoresCompanion(
        customerEnabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateCashRoundingSettings({
    required String storeId,
    required bool enabled,
    required int increment,
    required String mode,
  }) {
    return (update(stores)..where((tbl) => tbl.id.equals(storeId))).write(
      StoresCompanion(
        cashRoundingEnabled: Value(enabled),
        cashRoundingIncrement: Value(increment),
        cashRoundingMode: Value(mode),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateSubscription({
    required String storeId,
    required String plan,
    required String status,
    DateTime? expiresAt,
  }) {
    return (update(stores)..where((tbl) => tbl.id.equals(storeId))).write(
      StoresCompanion(
        subscriptionPlan: Value(plan),
        subscriptionStatus: Value(status),
        subscriptionExpiresAt: Value(expiresAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

