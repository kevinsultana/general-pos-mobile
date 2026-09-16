import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/i_customer_repository.dart';
import '../local/app_database.dart';
import '../local/daos/customer_dao.dart';

class CustomerRepositoryImpl implements ICustomerRepository {
  final CustomerDao _customerDao;
  final Uuid _uuid;
  final AppDatabase? _db;
  final bool _isCloudMode;
  final String? _deviceId;

  CustomerRepositoryImpl(
    this._customerDao, {
    Uuid? uuid,
    this._db,
    this._isCloudMode = false,
    this._deviceId,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Customer>> getCustomers(String storeId) {
    return _customerDao.getAllCustomers(storeId);
  }

  @override
  Stream<List<Customer>> watchCustomers(String storeId) {
    return _customerDao.watchAllCustomers(storeId);
  }

  @override
  Future<List<Customer>> searchCustomers(String storeId, String query) {
    return _customerDao.searchCustomers(storeId, query);
  }

  @override
  Future<Customer?> getCustomerById(String id) {
    return _customerDao.getCustomerById(id);
  }

  @override
  Future<String> createCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final now = DateTime.now();
    final customerId = _uuid.v4();

    await _customerDao.insertCustomer(
      CustomersCompanion(
        id: Value(customerId),
        storeId: Value(storeId),
        name: Value(name.trim()),
        phone: Value(phone?.trim()),
        email: Value(email?.trim()),
        notes: Value(notes?.trim()),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    if (_isCloudMode && _db != null) {
      await _db.syncEventDao.insertRawEvent(
        id: _uuid.v4(),
        storeId: storeId,
        deviceId: _deviceId ?? 'pos-device',
        entityType: 'Customer',
        entityId: customerId,
        operation: 'CREATE_CUSTOMER',
        payload: jsonEncode({
          'id': customerId,
          'name': name.trim(),
          'phone': phone?.trim(),
          'email': email?.trim(),
          'notes': notes?.trim(),
        }),
        status: 'PENDING',
        createdAt: now,
      );
    }

    return customerId;
  }

  @override
  Future<void> updateCustomer({
    required String id,
    required String storeId,
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final existing = await _customerDao.getCustomerById(id);
    if (existing == null) {
      throw Exception('Pelanggan dengan ID $id tidak ditemukan');
    }

    final now = DateTime.now();
    await _customerDao.updateCustomer(
      CustomersCompanion(
        id: Value(id),
        storeId: Value(storeId),
        name: Value(name.trim()),
        phone: Value(phone?.trim()),
        email: Value(email?.trim()),
        notes: Value(notes?.trim()),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    if (_isCloudMode && _db != null) {
      await _db.syncEventDao.insertRawEvent(
        id: _uuid.v4(),
        storeId: storeId,
        deviceId: _deviceId ?? 'pos-device',
        entityType: 'Customer',
        entityId: id,
        operation: 'UPDATE_CUSTOMER',
        payload: jsonEncode({
          'id': id,
          'name': name.trim(),
          'phone': phone?.trim(),
          'email': email?.trim(),
          'notes': notes?.trim(),
        }),
        status: 'PENDING',
        createdAt: now,
      );
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final existing = await _customerDao.getCustomerById(id);
    await _customerDao.deleteCustomer(id);

    if (_isCloudMode && _db != null && existing != null) {
      await _db.syncEventDao.insertRawEvent(
        id: _uuid.v4(),
        storeId: existing.storeId,
        deviceId: _deviceId ?? 'pos-device',
        entityType: 'Customer',
        entityId: id,
        operation: 'DELETE_CUSTOMER',
        payload: jsonEncode({
          'id': id,
        }),
        status: 'PENDING',
        createdAt: DateTime.now(),
      );
    }
  }
}
