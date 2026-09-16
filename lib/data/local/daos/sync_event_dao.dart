import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'sync_event_dao.g.dart';

@DriftAccessor(tables: [SyncEvents, SyncCursors])
class SyncEventDao extends DatabaseAccessor<AppDatabase>
    with _$SyncEventDaoMixin {
  SyncEventDao(super.db);

  // ──────────────── SyncEvents ────────────────

  /// Insert a new sync event. Uses insertOrIgnore to avoid duplicates on eventId.
  Future<void> insertEvent(SyncEventsCompanion event) async {
    await into(syncEvents).insert(event, mode: InsertMode.insertOrIgnore);
  }

  /// Get PENDING events for a store, ordered by creation time.
  Future<List<SyncEvent>> getPendingEvents(String storeId,
      {int limit = 50}) {
    return (select(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) & e.status.equals('PENDING'))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Get FAILED events for a store.
  Future<List<SyncEvent>> getFailedEvents(String storeId) {
    return (select(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) & e.status.equals('FAILED'))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
  }

  /// Stream of pending event count for real-time UI.
  Stream<int> watchPendingCount(String storeId) {
    final countCol = syncEvents.id.count();
    final query = selectOnly(syncEvents)
      ..addColumns([countCol])
      ..where(
          syncEvents.storeId.equals(storeId) &
          syncEvents.status.equals('PENDING'));
    return query.map((row) => row.read(countCol) ?? 0).watchSingle();
  }

  /// Mark event as PROCESSING (in-flight, prevents re-queue).
  Future<void> markProcessing(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(status: const Value('PROCESSING')),
    );
  }

  /// Mark event as SYNCED.
  Future<void> markSynced(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(
        status: const Value('SYNCED'),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark event as FAILED and increment attempt count.
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

  /// Reset a FAILED event back to PENDING for retry.
  Future<void> retryFailed(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(status: const Value('PENDING')),
    );
  }

  /// Mark event as CONFLICT (server-side conflict detected).
  Future<void> markConflict(String id) {
    return (update(syncEvents)..where((e) => e.id.equals(id))).write(
      SyncEventsCompanion(
        status: const Value('CONFLICT'),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get all CONFLICT events for a store.
  Future<List<SyncEvent>> getConflictEvents(String storeId) {
    return (select(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) & e.status.equals('CONFLICT'))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
  }

  /// Get all events currently marked PROCESSING for a store.
  Future<List<SyncEvent>> getProcessingEvents(String storeId) {
    return (select(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) & e.status.equals('PROCESSING'))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
  }

  /// Reset stale PROCESSING events (stuck in-flight > [staleThreshold]) back to PENDING.
  /// This handles crash/network-abort recovery so events are not permanently stuck.
  Future<int> resetStaleProcessing(
    String storeId, {
    Duration staleThreshold = const Duration(minutes: 5),
  }) async {
    final cutoff = DateTime.now().subtract(staleThreshold);
    return (update(syncEvents)
          ..where((e) =>
              e.storeId.equals(storeId) &
              e.status.equals('PROCESSING') &
              e.lastAttemptAt.isSmallerOrEqualValue(cutoff)))
        .write(SyncEventsCompanion(status: const Value('PENDING')));
  }

  // ──────────────── SyncCursors ────────────────

  /// Get the stored cursor for this device.
  Future<SyncCursor?> getCursor(String storeId, String deviceId) {
    return (select(syncCursors)
          ..where((c) =>
              c.storeId.equals(storeId) & c.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  /// Upsert the sync cursor for a device.
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
