import '../local/app_database.dart';
import 'api_client.dart';

/// Service to completely wipe all local databases and secure storage
/// to simulate a fresh app installation.
class DataResetService {
  final AppDatabase localDb;
  final AppDatabase cloudDb;
  final TokenStorage tokenStorage;

  const DataResetService({
    required this.localDb,
    required this.cloudDb,
    required this.tokenStorage,
  });

  /// Clears all tables in both local and cloud cache databases,
  /// and deletes all tokens and preferences from secure storage.
  Future<void> resetEverything() async {
    // 1. Wipe local database tables
    await _clearDatabase(localDb);

    // 2. Wipe cloud cache database tables
    await _clearDatabase(cloudDb);

    // 3. Wipe all secure storage keys
    await tokenStorage.clearAll();
  }

  /// Wipes all tables in the given database.
  Future<void> _clearDatabase(AppDatabase db) async {
    await db.transaction(() async {
      await db.customStatement('DELETE FROM "sync_events";');
      await db.customStatement('DELETE FROM "stock_movements";');
      await db.customStatement('DELETE FROM "transaction_items";');
      await db.customStatement('DELETE FROM "payments";');
      await db.customStatement('DELETE FROM "transactions";');
      await db.customStatement('DELETE FROM "product_variants";');
      await db.customStatement('DELETE FROM "products";');
      await db.customStatement('DELETE FROM "categories";');
      await db.customStatement('DELETE FROM "promotions";');
      await db.customStatement('DELETE FROM "customers";');
      await db.customStatement('DELETE FROM "printers";');
      await db.customStatement('DELETE FROM "users";');
      await db.customStatement('DELETE FROM "stores";');
      try {
        await db.customStatement('DELETE FROM "sync_cursors";');
      } catch (_) {}
    });
  }

  /// Clears only the local database (used after successful cloud migration).
  Future<void> clearLocalDatabaseOnly() async {
    await _clearDatabase(localDb);
  }
}
