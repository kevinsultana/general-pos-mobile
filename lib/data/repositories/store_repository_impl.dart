import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

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
  Future<Store?> getCurrentStore() async {
    final store = await _storeDao.getFirstStore();
    if (store != null) {
      await _storeDao.healAllOrphanRecords(store.id);
    }
    return store;
  }

  @override
  Stream<Store?> watchCurrentStore() {
    return _storeDao.watchFirstStore().asyncMap((store) async {
      if (store != null) {
        await _storeDao.healAllOrphanRecords(store.id);
      }
      return store;
    });
  }

  @override
  Future<void> saveStore(StoresCompanion store) => _storeDao.insertStore(store);

  @override
  Future<void> setCustomerEnabled(String storeId, bool enabled) =>
      _storeDao.setCustomerEnabled(storeId, enabled);

  @override
  Future<void> setOrderTypeEnabled(String storeId, bool enabled) =>
      _storeDao.setOrderTypeEnabled(storeId, enabled);

  @override
  Future<void> updateOrderTypes({
    required String storeId,
    required List<String> orderTypes,
  }) =>
      _storeDao.updateOrderTypes(
        storeId: storeId,
        orderTypes: orderTypes,
      );

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
  Future<void> updateSubscription({
    required String storeId,
    required String plan,
    required String status,
    DateTime? expiresAt,
  }) =>
      _storeDao.updateSubscription(
        storeId: storeId,
        plan: plan,
        status: status,
        expiresAt: expiresAt,
      );

  @override
  Future<Store> ensureDefaultStore() => _storeDao.ensureDefaultStore();

  @override
  Future<bool> isStoreRegistered() => _storeDao.isStoreRegistered();

  @override
  Future<Store> registerLocalStore({
    required String name,
    required String address,
    required String phone,
    String? ownerName,
    required String adminUsername,
    required String adminPassword,
    required String adminDisplayName,
    String? customStoreId,
    String? customAdminUserId,
  }) {
    const uuid = Uuid();
    final storeId = customStoreId ?? uuid.v4();
    final adminUserId = customAdminUserId ?? uuid.v4();
    final passwordHash = sha256.convert(utf8.encode(adminPassword)).toString();

    return _storeDao.registerLocalStore(
      storeId: storeId,
      name: name,
      address: address,
      phone: phone,
      ownerName: ownerName,
      adminUserId: adminUserId,
      adminUsername: adminUsername,
      adminPasswordHash: passwordHash,
      adminDisplayName: adminDisplayName,
    );
  }

  @override
  Future<User?> getAdminUser([String? storeId]) => _storeDao.getAdminUser(storeId);

  @override
  Future<void> updateStoreProfile({
    required String storeId,
    required String name,
    required String address,
    required String phone,
    String? ownerName,
  }) =>
      _storeDao.updateStoreProfile(
        storeId: storeId,
        name: name,
        address: address,
        phone: phone,
        ownerName: ownerName,
      );
}

