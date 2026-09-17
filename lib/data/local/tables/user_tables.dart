import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get username => text()();
  TextColumn get email => text().nullable()();
  TextColumn get passwordHash => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text().withDefault(const Constant('ADMIN'))();
  TextColumn get roleId => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
