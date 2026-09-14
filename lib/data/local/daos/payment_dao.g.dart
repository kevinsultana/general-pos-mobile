// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_dao.dart';

// ignore_for_file: type=lint
mixin _$PaymentDaoMixin on DatabaseAccessor<AppDatabase> {
  $PaymentsTable get payments => attachedDatabase.payments;
  $PaymentMethodsTable get paymentMethods => attachedDatabase.paymentMethods;
  PaymentDaoManager get managers => PaymentDaoManager(this);
}

class PaymentDaoManager {
  final _$PaymentDaoMixin _db;
  PaymentDaoManager(this._db);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
  $$PaymentMethodsTableTableManager get paymentMethods =>
      $$PaymentMethodsTableTableManager(
        _db.attachedDatabase,
        _db.paymentMethods,
      );
}
