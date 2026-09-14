// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_sync_event_dao.dart';

// ignore_for_file: type=lint
mixin _$CloudSyncEventDaoMixin on DatabaseAccessor<CloudDatabase> {
  $SyncEventsTable get syncEvents => attachedDatabase.syncEvents;
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  CloudSyncEventDaoManager get managers => CloudSyncEventDaoManager(this);
}

class CloudSyncEventDaoManager {
  final _$CloudSyncEventDaoMixin _db;
  CloudSyncEventDaoManager(this._db);
  $$SyncEventsTableTableManager get syncEvents =>
      $$SyncEventsTableTableManager(_db.attachedDatabase, _db.syncEvents);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
}
