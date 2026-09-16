import 'package:drift/drift.dart';
import '../cloud_database.dart';
import '../tables/sync_tables.dart';

part 'cloud_sync_event_dao.g.dart';

/// SyncEventDao for the Cloud database (cloud_cache.sqlite).
/// Mirrors [SyncEventDao] but bound to [CloudDatabase].
@DriftAccessor(tables: [SyncEvents, SyncCursors])
class CloudSyncEventDao extends DatabaseAccessor<CloudDatabase>
    with _$CloudSyncEventDaoMixin {
  CloudSyncEventDao(super.db);

  // ──────────────── SyncEvents ────────────────

  Future<void> insertEvent(SyncEventsCompanion event) async {
    await into(syncEvents).insert(event, mode: InsertMode.insertOrIgnore);
  }

  Future<List<SyncEvent>> getPendingEvents(String storeId,
      {int limit = 50}) {
    return (select(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) & e.status.equals('PENDING'))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncEvent>> getFailedEvents(String storeId) {
    return (select(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) & e.status.equals('FAILED'))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
  }

  Stream<int> watchPendingCount(String storeId) {
    final countCol = syncEvents.id.count();
    final query = selectOnly(syncEvents)
      ..addColumns([countCol])
      ..where(syncEvents.storeId.equals(storeId) &
          syncEvents.status.equals('PENDING'));
    return query.map((row) => row.read(countCol) ?? 0).watchSingle();
  }

  Future<void> markProcessing(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(status: const Value('PROCESSING')),
    );
  }

  Future<void> markSynced(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(
        status: const Value('SYNCED'),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markFailed(String id) async {
    final event = await (select(syncEvents)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (event == null) return;
    await (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(
        status: const Value('FAILED'),
        attemptCount: Value(event.attemptCount + 1),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> retryFailed(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(status: const Value('PENDING')),
    );
  }

  // ──────────────── SyncCursors ────────────────

  Future<SyncCursor?> getCursor(String storeId, String deviceId) {
    return (select(syncCursors)
          ..where((c) =>
              c.storeId.equals(storeId) & c.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  Future<void> updateCursor(
      String storeId, String deviceId, BigInt cursor) async {
    final id = '${storeId}_$deviceId';
    await into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(
        id: id,
        storeId: storeId,
        deviceId: deviceId,
        cursor: Value(cursor),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
