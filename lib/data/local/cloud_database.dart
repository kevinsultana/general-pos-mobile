import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/sync_tables.dart';
import 'daos/cloud_sync_event_dao.dart';

part 'cloud_database.g.dart';

/// Separate Drift database for Cloud mode.
/// Filename: [cloud_cache.sqlite] — NEVER shares data with [local.sqlite].
///
/// This database focuses on the sync queue only (Phase 10).
/// Future phases will add more tables as needed.
@DriftDatabase(
  tables: [
    SyncEvents,
    SyncCursors,
  ],
  daos: [
    CloudSyncEventDao,
  ],
)
class CloudDatabase extends _$CloudDatabase {
  CloudDatabase([QueryExecutor? e]) : super(e ?? _openConnection('cloud_cache.sqlite'));

  /// For testing
  CloudDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static LazyDatabase _openConnection(String dbName) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, dbName));
      return NativeDatabase.createInBackground(file);
    });
  }
}
