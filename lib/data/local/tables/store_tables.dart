import 'package:drift/drift.dart';

class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get logoReference => text().nullable()();

  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  TextColumn get timezone => text().withDefault(const Constant('Asia/Jakarta'))();
  TextColumn get language => text().withDefault(const Constant('id'))();

  TextColumn get businessType => text().withDefault(const Constant('GENERAL'))();

  BoolColumn get customerEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get draftEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get splitPaymentEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get refundEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get partialRefundEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get restaurantEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get kitchenPrintingEnabled => boolean().withDefault(const Constant(false))();

  // Cash Rounding Settings
  BoolColumn get cashRoundingEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get cashRoundingIncrement => integer().withDefault(const Constant(100))();
  TextColumn get cashRoundingMode => text().withDefault(const Constant('ROUND_NEAREST'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
