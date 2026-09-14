import 'package:drift/drift.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get transactionNumber => text()();
  TextColumn get customerId => text().nullable()();

  // Status: DRAFT, COMPLETED, CANCELLED
  TextColumn get status => text()();
  TextColumn get orderType => text().nullable()();
  TextColumn get queueNumber => text().nullable()();

  IntColumn get subtotal => integer()();
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

  IntColumn get quantity => integer()();
  IntColumn get unitPrice => integer()();
  IntColumn get unitCostSnapshot => integer()(); // Critical for accurate gross profit

  TextColumn get discountType => text().nullable()();
  IntColumn get discountValue => integer().nullable()();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();

  IntColumn get subtotal => integer()();
  IntColumn get total => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
