// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_event_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncEventDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncEventsTable get syncEvents => attachedDatabase.syncEvents;
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  SyncEventDaoManager get managers => SyncEventDaoManager(this);
}

class SyncEventDaoManager {
  final _$SyncEventDaoMixin _db;
  SyncEventDaoManager(this._db);
  $$SyncEventsTableTableManager get syncEvents =>
      $$SyncEventsTableTableManager(_db.attachedDatabase, _db.syncEvents);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
}
