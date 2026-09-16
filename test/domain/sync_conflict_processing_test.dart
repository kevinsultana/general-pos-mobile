import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/daos/sync_event_dao.dart';
import 'package:mobile_pos/data/local/cloud_database.dart' as cloud;
import 'package:mobile_pos/data/local/daos/cloud_sync_event_dao.dart';

void main() {
  group('P3.2 Sync PROCESSING & CONFLICT Status Lifecycle Tests', () {
    late AppDatabase localDb;
    late cloud.CloudDatabase cloudDb;
    late SyncEventDao localDao;
    late CloudSyncEventDao cloudDao;

    const storeId = 'store-p32-01';

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      localDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      cloudDb = cloud.CloudDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      localDao = SyncEventDao(localDb);
      cloudDao = CloudSyncEventDao(cloudDb);
    });

    tearDown(() async {
      await localDb.close();
      await cloudDb.close();
    });

    test('Local DAO: transitions through PENDING -> PROCESSING -> CONFLICT -> PENDING (retry)', () async {
      const eventId = 'evt-conflict-01';
      final now = DateTime.now();

      // 1. Insert PENDING event
      await localDao.insertEvent(
        SyncEventsCompanion.insert(
          id: eventId,
          storeId: storeId,
          deviceId: 'dev-01',
          entityType: 'Product',
          entityId: 'prod-01',
          operation: 'UPDATE_PRODUCT',
          payload: '{"name":"Updated Item"}',
          status: 'PENDING',
          createdAt: now,
        ),
      );

      var pending = await localDao.getPendingEvents(storeId);
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(eventId));

      // 2. Mark PROCESSING
      await localDao.markProcessing(eventId);
      pending = await localDao.getPendingEvents(storeId);
      expect(pending, isEmpty);

      var processing = await localDao.getProcessingEvents(storeId);
      expect(processing.length, equals(1));
      expect(processing.first.id, equals(eventId));

      // 3. Mark CONFLICT (server detected concurrent edit)
      await localDao.markConflict(eventId);
      processing = await localDao.getProcessingEvents(storeId);
      expect(processing, isEmpty);

      var conflicts = await localDao.getConflictEvents(storeId);
      expect(conflicts.length, equals(1));
      expect(conflicts.first.id, equals(eventId));
      expect(conflicts.first.status, equals('CONFLICT'));

      // 4. Retry conflict: resets to PENDING
      await localDao.retryFailed(eventId);
      conflicts = await localDao.getConflictEvents(storeId);
      expect(conflicts, isEmpty);

      pending = await localDao.getPendingEvents(storeId);
      expect(pending.length, equals(1));
      expect(pending.first.status, equals('PENDING'));
    });

    test('Cloud DAO: resetStaleProcessing only resets events older than threshold', () async {
      final now = DateTime.now();
      final tenMinsAgo = now.subtract(const Duration(minutes: 10));

      // Event A: Stale PROCESSING event (last attempt 10 mins ago)
      await cloudDao.insertEvent(
        cloud.SyncEventsCompanion.insert(
          id: 'evt-stale-01',
          storeId: storeId,
          deviceId: 'dev-01',
          entityType: 'Transaction',
          entityId: 'trx-01',
          operation: 'COMPLETE_TRANSACTION',
          payload: '{}',
          status: 'PROCESSING',
          lastAttemptAt: Value(tenMinsAgo),
          createdAt: tenMinsAgo,
        ),
      );

      // Event B: Fresh PROCESSING event (last attempt just now)
      await cloudDao.insertEvent(
        cloud.SyncEventsCompanion.insert(
          id: 'evt-fresh-02',
          storeId: storeId,
          deviceId: 'dev-01',
          entityType: 'Transaction',
          entityId: 'trx-02',
          operation: 'COMPLETE_TRANSACTION',
          payload: '{}',
          status: 'PROCESSING',
          lastAttemptAt: Value(now),
          createdAt: now,
        ),
      );

      var processing = await cloudDao.getProcessingEvents(storeId);
      expect(processing.length, equals(2));

      // Run recovery with 5 min threshold
      final recoveredCount = await cloudDao.resetStaleProcessing(
        storeId,
        staleThreshold: const Duration(minutes: 5),
      );
      expect(recoveredCount, equals(1));

      // Fresh event remains PROCESSING
      processing = await cloudDao.getProcessingEvents(storeId);
      expect(processing.length, equals(1));
      expect(processing.first.id, equals('evt-fresh-02'));

      // Stale event is back to PENDING
      final pending = await cloudDao.getPendingEvents(storeId);
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('evt-stale-01'));
      expect(pending.first.status, equals('PENDING'));
    });

    test('Cloud DAO: getConflictEvents and retryFailed lifecycle', () async {
      const conflictId = 'cloud-conflict-99';
      await cloudDao.insertEvent(
        cloud.SyncEventsCompanion.insert(
          id: conflictId,
          storeId: storeId,
          deviceId: 'dev-cloud-01',
          entityType: 'Customer',
          entityId: 'cust-99',
          operation: 'UPDATE_CUSTOMER',
          payload: '{"name":"Jane Doe"}',
          status: 'CONFLICT',
          createdAt: DateTime.now(),
        ),
      );

      var conflicts = await cloudDao.getConflictEvents(storeId);
      expect(conflicts.length, equals(1));
      expect(conflicts.first.id, equals(conflictId));
      expect(conflicts.first.status, equals('CONFLICT'));

      // Retry conflict resets it to PENDING
      await cloudDao.retryFailed(conflictId);
      conflicts = await cloudDao.getConflictEvents(storeId);
      expect(conflicts, isEmpty);

      final pending = await cloudDao.getPendingEvents(storeId);
      expect(pending.any((e) => e.id == conflictId), isTrue);
    });
  });
}
