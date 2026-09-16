import 'package:drift/drift.dart';

class Promotions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();

  // 'PERCENTAGE' or 'FIXED_AMOUNT' (legacy 'FIXED' is normalized to 'FIXED_AMOUNT')
  TextColumn get discountType => text()();
  /// Value of discount: percentage (e.g. 10 for 10%) or fixed Rupiah nominal (e.g. 10000).
  IntColumn get discountValue => integer()();
  /// Corresponds to Prisma `minimumPurchase Decimal(18,2)` in backend.
  /// Stored as whole Rupiah without fractional cents (1:1 scale, Rp 1 = 1 unit).
  /// E.g. Rp 50.000 = 50000. DO NOT multiply or divide by 100/1000.
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
