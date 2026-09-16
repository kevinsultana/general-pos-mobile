import 'package:drift/drift.dart';

class PaymentMethods extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  // PaymentMethodType: CASH, QRIS, TRANSFER, DEBIT, CREDIT
  TextColumn get type => text()();
  TextColumn get name => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get configuration => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get paymentMethodId => text()();

  IntColumn get amount => integer()();
  IntColumn get roundingAmount => integer().withDefault(const Constant(0))();

  // PaymentStatus: PENDING, COMPLETED, VOIDED (Prisma enum source of truth)
  TextColumn get status => text()();
  TextColumn get metadata => text().nullable()(); // JSON string

  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
