import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_tables.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  Future<void> ensureTableExists() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "users" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "store_id" TEXT NOT NULL,
        "username" TEXT NOT NULL,
        "email" TEXT,
        "password_hash" TEXT NOT NULL,
        "display_name" TEXT NOT NULL,
        "role" TEXT NOT NULL DEFAULT 'ADMIN',
        "role_id" TEXT,
        "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)),
        "created_at" INTEGER NOT NULL,
        "updated_at" INTEGER NOT NULL
      );
    ''');
  }

  Future<bool> hasAdminUser([String? storeId]) async {
    await ensureTableExists();
    final query = select(users)
      ..where((tbl) => tbl.role.equals('ADMIN') & tbl.active.equals(true));
    if (storeId != null && storeId.isNotEmpty) {
      query.where((tbl) => tbl.storeId.equals(storeId));
    }
    final admin = await (query..limit(1)).getSingleOrNull();
    return admin != null;
  }

  Future<User?> getAdminUser([String? storeId]) async {
    await ensureTableExists();
    final query = select(users)
      ..where((tbl) => tbl.role.equals('ADMIN') & tbl.active.equals(true));
    if (storeId != null && storeId.isNotEmpty) {
      query.where((tbl) => tbl.storeId.equals(storeId));
    }
    return (query..limit(1)).getSingleOrNull();
  }

  Future<List<User>> getUsersByStore(String storeId) async {
    await ensureTableExists();
    return (select(users)..where((tbl) => tbl.storeId.equals(storeId))).get();
  }

  Future<User?> getUserByUsername(String storeId, String username) async {
    await ensureTableExists();
    return (select(users)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) & tbl.username.equals(username)))
        .getSingleOrNull();
  }

  Future<void> insertUser(UsersCompanion user) async {
    await ensureTableExists();
    await into(users).insert(user, mode: InsertMode.insertOrReplace);
  }

  Future<int> countUsers() async {
    await ensureTableExists();
    final countExp = users.id.count();
    final query = selectOnly(users)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }
}
