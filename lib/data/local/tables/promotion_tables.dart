import 'package:drift/drift.dart';

class Promotions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();

  // 'PERCENTAGE' or 'FIXED'
  TextColumn get discountType => text()();
  IntColumn get discountValue => integer()();
  IntColumn get minSpend => integer().withDefault(const Constant(0))();

  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get productId => text().nullable()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
