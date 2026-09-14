import 'package:drift/drift.dart';

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get productId => text()();
  TextColumn get variantId => text().nullable()();

  // Type: IN, SALE, ADJUSTMENT, CANCEL, REFUND
  TextColumn get type => text()();

  // Signed integer with scale 1000 (e.g., 1 unit = 1000, -2 units = -2000)
  IntColumn get quantityDelta => integer()();
  IntColumn get unitCost => integer().nullable()();

  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get createdById => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
