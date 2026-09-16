import 'package:drift/drift.dart';

class SyncEvents extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get deviceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()(); // JSON string
  TextColumn get status => text()(); // PENDING, SYNCED, FAILED
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncCursors extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get deviceId => text()();
  Int64Column get cursor => int64().withDefault(Constant(BigInt.zero))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {storeId, deviceId},
      ];
}
