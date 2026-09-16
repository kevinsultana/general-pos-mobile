import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/daos/sync_event_dao.dart';
import 'package:mobile_pos/data/local/cloud_database.dart' as cloud;
import 'package:mobile_pos/data/local/daos/cloud_sync_event_dao.dart';

void main() {
  group('P2.5 SyncCursor BigInt Migration Tests', () {
    late AppDatabase localDb;
    late cloud.CloudDatabase cloudDb;
    late SyncEventDao localDao;
    late CloudSyncEventDao cloudDao;

    const storeId = 'store-bigint-01';
    const deviceId = 'device-pos-01';

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

    test('Local SyncEventDao: inserts and updates BigInt cursor without 32-bit overflow', () async {
      // 1. Initial cursor check (null before insert)
      final initial = await localDao.getCursor(storeId, deviceId);
      expect(initial, isNull);

      // 2. Insert epoch millisecond timestamp > 2^31 - 1 (2,147,483,647)
      // e.g. 1,773,663,000,000 (~ Year 2026 in ms)
      final epochTimestamp = BigInt.parse('1773663000000');
      await localDao.updateCursor(storeId, deviceId, epochTimestamp);

      final row = await localDao.getCursor(storeId, deviceId);
      expect(row, isNotNull);
      expect(row!.cursor, equals(epochTimestamp));
      expect(row.cursor, isA<BigInt>());
      expect(row.cursor > BigInt.from(2147483647), isTrue);

      // 3. Sequential update with a larger timestamp
      final nextTimestamp = epochTimestamp + BigInt.from(60000); // +1 minute
      await localDao.updateCursor(storeId, deviceId, nextTimestamp);

      final updated = await localDao.getCursor(storeId, deviceId);
      expect(updated, isNotNull);
      expect(updated!.cursor, equals(nextTimestamp));
    });

    test('CloudSyncEventDao: inserts and updates BigInt cursor for cloud cache', () async {
      final initial = await cloudDao.getCursor(storeId, deviceId);
      expect(initial, isNull);

      final epochTimestamp = BigInt.parse('1773663999999');
      await cloudDao.updateCursor(storeId, deviceId, epochTimestamp);

      final row = await cloudDao.getCursor(storeId, deviceId);
      expect(row, isNotNull);
      expect(row!.cursor, equals(epochTimestamp));
      expect(row.cursor, isA<BigInt>());
      expect(row.cursor.toString(), equals('1773663999999'));
    });

    test('Different device IDs maintain independent BigInt cursors for the same store', () async {
      const deviceId2 = 'device-pos-02';
      final cursor1 = BigInt.parse('1773663000000');
      final cursor2 = BigInt.parse('1773663500000');

      await localDao.updateCursor(storeId, deviceId, cursor1);
      await localDao.updateCursor(storeId, deviceId2, cursor2);

      final row1 = await localDao.getCursor(storeId, deviceId);
      final row2 = await localDao.getCursor(storeId, deviceId2);

      expect(row1?.cursor, equals(cursor1));
      expect(row2?.cursor, equals(cursor2));
    });
  });
}
