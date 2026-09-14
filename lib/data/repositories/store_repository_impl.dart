import '../../domain/repositories/i_store_repository.dart';
import '../local/app_database.dart';
import '../local/daos/store_dao.dart';

class StoreRepositoryImpl implements IStoreRepository {
  final StoreDao _storeDao;

  StoreRepositoryImpl(this._storeDao);

  @override
  Future<Store?> getStore(String id) => _storeDao.getStoreById(id);

  @override
  Stream<Store?> watchStore(String id) => _storeDao.watchStoreById(id);

  @override
  Future<Store?> getCurrentStore() => _storeDao.getFirstStore();

  @override
  Stream<Store?> watchCurrentStore() => _storeDao.watchFirstStore();

  @override
  Future<void> saveStore(StoresCompanion store) => _storeDao.insertStore(store);

  @override
  Future<void> setCustomerEnabled(String storeId, bool enabled) =>
      _storeDao.setCustomerEnabled(storeId, enabled);

  @override
  Future<void> updateCashRoundingSettings({
    required String storeId,
    required bool enabled,
    required int increment,
    required String mode,
  }) =>
      _storeDao.updateCashRoundingSettings(
        storeId: storeId,
        enabled: enabled,
        increment: increment,
        mode: mode,
      );

  @override
  Future<Store> ensureDefaultStore() => _storeDao.ensureDefaultStore();
}

