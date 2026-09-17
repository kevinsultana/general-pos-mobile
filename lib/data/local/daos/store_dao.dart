import 'dart:convert';
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
      orderTypeEnabled: const Value(true),
      orderTypesJson: const Value('["Dine In","Takeaway","Delivery","Online"]'),
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

  Future<void> setOrderTypeEnabled(String storeId, bool enabled) {
    return (update(stores)..where((tbl) => tbl.id.equals(storeId))).write(
      StoresCompanion(
        orderTypeEnabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateOrderTypes({
    required String storeId,
    required List<String> orderTypes,
  }) {
    return (update(stores)..where((tbl) => tbl.id.equals(storeId))).write(
      StoresCompanion(
        orderTypesJson: Value(jsonEncode(orderTypes)),
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

  Future<bool> isStoreRegistered() async {
    final store = await getFirstStore();
    if (store == null) return false;
    return db.userDao.hasAdminUser(store.id);
  }

  Future<void> healAllOrphanRecords(String storeId) async {
    if (storeId == 'store-default-01' || storeId.isEmpty) return;
    try {
      await customStatement("UPDATE products SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      await customStatement("UPDATE categories SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      await customStatement("UPDATE transactions SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      await customStatement("UPDATE stock_movements SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      await customStatement("UPDATE customers SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      await customStatement("UPDATE promotions SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      await customStatement("UPDATE printers SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
    } catch (_) {}
  }

  Future<Store> registerLocalStore({
    required String storeId,
    required String name,
    required String address,
    required String phone,
    String? ownerName,
    required String adminUserId,
    required String adminUsername,
    required String adminPasswordHash,
    required String adminDisplayName,
  }) async {
    final now = DateTime.now();
    return db.transaction(() async {
      // Clean up any unconfigured placeholder store if no admin was assigned
      final placeholder = await getStoreById('store-default-01');
      if (placeholder != null) {
        final hasAdmin = await db.userDao.hasAdminUser('store-default-01');
        if (!hasAdmin) {
          await (delete(stores)..where((tbl) => tbl.id.equals('store-default-01'))).go();
        }
      }

      final storeCompanion = StoresCompanion.insert(
        id: storeId,
        name: name,
        ownerName: Value(ownerName),
        address: Value(address),
        phone: Value(phone),
        currency: const Value('IDR'),
        timezone: const Value('Asia/Jakarta'),
        language: const Value('id'),
        businessType: const Value('GENERAL'),
        customerEnabled: const Value(true),
        draftEnabled: const Value(true),
        splitPaymentEnabled: const Value(true),
        refundEnabled: const Value(true),
        cashRoundingEnabled: const Value(true),
        cashRoundingIncrement: const Value(100),
        cashRoundingMode: const Value('ROUND_NEAREST'),
        subscriptionPlan: const Value('FREE'),
        subscriptionStatus: const Value('INACTIVE'),
        subscriptionExpiresAt: const Value(null),
        orderTypeEnabled: const Value(true),
        orderTypesJson: const Value('["Dine In","Takeaway","Delivery","Online"]'),
        createdAt: now,
        updatedAt: now,
      );
      await insertStore(storeCompanion);

      final userCompanion = UsersCompanion.insert(
        id: adminUserId,
        storeId: storeId,
        username: adminUsername,
        displayName: adminDisplayName,
        passwordHash: adminPasswordHash,
        role: const Value('ADMIN'),
        active: const Value(true),
        createdAt: now,
        updatedAt: now,
      );
      await db.userDao.insertUser(userCompanion);

      // Auto-migrate all existing business records to the new storeId
      await healAllOrphanRecords(storeId);

      final created = await getStoreById(storeId);
      return created!;
    });
  }

  Future<void> updateStoreProfile({
    required String storeId,
    required String name,
    required String address,
    required String phone,
    String? ownerName,
  }) {
    return (update(stores)..where((tbl) => tbl.id.equals(storeId))).write(
      StoresCompanion(
        name: Value(name),
        address: Value(address),
        phone: Value(phone),
        ownerName: Value(ownerName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<User?> getAdminUser([String? storeId]) => db.userDao.getAdminUser(storeId);
}

