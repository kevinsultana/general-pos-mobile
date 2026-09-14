import 'package:drift/drift.dart';

class Refunds extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  IntColumn get amount => integer()();
  TextColumn get reason => text()();
  // Status: COMPLETED, CANCELLED
  TextColumn get status => text()();
  TextColumn get createdById => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class RefundItems extends Table {
  TextColumn get id => text()();
  TextColumn get refundId => text()();
  TextColumn get transactionItemId => text()();
  IntColumn get quantity => integer()();
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
