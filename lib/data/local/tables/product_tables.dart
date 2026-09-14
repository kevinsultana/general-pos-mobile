import 'package:drift/drift.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();

  IntColumn get cost => integer()();
  IntColumn get sellingPrice => integer()();
  IntColumn get stock => integer()();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(0))();
  TextColumn get imageReference => text().nullable()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get discontinued => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {storeId, name},
      ];
}

class ProductVariants extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();

  IntColumn get cost => integer()();
  IntColumn get sellingPrice => integer()();
  IntColumn get stock => integer()();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(0))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {productId, name},
      ];
}
