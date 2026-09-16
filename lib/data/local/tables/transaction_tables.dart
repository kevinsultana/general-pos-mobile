import 'package:drift/drift.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get transactionNumber => text()();
  TextColumn get customerId => text().nullable()();

  // Status: DRAFT, COMPLETED, CANCELLED, PARTIALLY_REFUNDED, REFUNDED
  TextColumn get status => text()();
  // OrderType: DINE_IN, TAKEAWAY, DELIVERY, ONLINE
  TextColumn get orderType => text().nullable()();
  TextColumn get queueNumber => text().nullable()();

  IntColumn get subtotal => integer()();
  // DiscountType: PERCENTAGE, FIXED_AMOUNT
  TextColumn get discountType => text().nullable()();
  IntColumn get discountValue => integer().nullable()();
  IntColumn get discountTotal => integer().withDefault(const Constant(0))();

  // Cash Rounding difference (+/-)
  IntColumn get roundingAmount => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  IntColumn get paidTotal => integer().withDefault(const Constant(0))();

  TextColumn get promotionId => text().nullable()();
  TextColumn get createdById => text().nullable()();
  TextColumn get cancelledById => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  DateTimeColumn get refundedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {storeId, transactionNumber},
      ];
}

class TransactionItems extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get productId => text()();
  TextColumn get variantId => text().nullable()();

  // Immutable historical snapshots
  TextColumn get productNameSnapshot => text()();
  TextColumn get variantNameSnapshot => text().nullable()();
  TextColumn get skuSnapshot => text().nullable()();
  TextColumn get barcodeSnapshot => text().nullable()();

  // DECIMAL(18,3) — supports fractional quantities (e.g. 0.5 kg, 1.5 L)
  RealColumn get quantity => real()();
  IntColumn get unitPrice => integer()();
  IntColumn get unitCostSnapshot => integer()(); // Critical for accurate gross profit

  // DiscountType: PERCENTAGE, FIXED_AMOUNT
  TextColumn get discountType => text().nullable()();
  IntColumn get discountValue => integer().nullable()();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();

  IntColumn get subtotal => integer()();
  IntColumn get total => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
