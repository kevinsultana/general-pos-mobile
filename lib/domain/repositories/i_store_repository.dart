import '../../data/local/app_database.dart';

abstract class IStoreRepository {
  Future<Store?> getStore(String id);
  Stream<Store?> watchStore(String id);
  Future<Store?> getCurrentStore();
  Stream<Store?> watchCurrentStore();
  Future<void> saveStore(StoresCompanion store);
  Future<void> setCustomerEnabled(String storeId, bool enabled);
  Future<void> updateCashRoundingSettings({
    required String storeId,
    required bool enabled,
    required int increment,
    required String mode,
  });
  Future<void> updateSubscription({
    required String storeId,
    required String plan,
    required String status,
    DateTime? expiresAt,
  });
  Future<Store> ensureDefaultStore();
}

