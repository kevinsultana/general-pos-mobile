import 'package:drift/drift.dart';

class Printers extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  // ConnectionType: BLUETOOTH, USB, NETWORK
  TextColumn get connectionType => text()();
  TextColumn get addressReference => text().nullable()();
  // Role: RECEIPT, KITCHEN, BOTH
  TextColumn get role => text()();
  IntColumn get receiptCopies => integer().withDefault(const Constant(1))();
  IntColumn get kitchenCopies => integer().withDefault(const Constant(1))();
  BoolColumn get autoPrint => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get configuration => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
