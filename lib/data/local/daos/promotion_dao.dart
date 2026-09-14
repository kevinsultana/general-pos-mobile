import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/promotion_tables.dart';

part 'promotion_dao.g.dart';

@DriftAccessor(tables: [Promotions])
class PromotionDao extends DatabaseAccessor<AppDatabase> with _$PromotionDaoMixin {
  PromotionDao(super.db);

  Future<void> ensureTableExists() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "promotions" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "store_id" TEXT NOT NULL,
        "name" TEXT NOT NULL,
        "code" TEXT,
        "discount_type" TEXT NOT NULL,
        "discount_value" INTEGER NOT NULL,
        "min_spend" INTEGER NOT NULL DEFAULT 0,
        "start_date" INTEGER,
        "end_date" INTEGER,
        "product_id" TEXT,
        "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)),
        "created_at" INTEGER NOT NULL,
        "updated_at" INTEGER NOT NULL
      );
    ''');
  }

  Future<List<Promotion>> getAllPromotions(String storeId) async {
    await ensureTableExists();
    return (select(promotions)
          ..where((tbl) => tbl.storeId.equals(storeId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Stream<List<Promotion>> watchAllPromotions(String storeId) async* {
    await ensureTableExists();
    yield* (select(promotions)
          ..where((tbl) => tbl.storeId.equals(storeId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  Future<Promotion?> getPromotionById(String id) async {
    await ensureTableExists();
    return (select(promotions)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Promotion?> getPromotionByCode(String storeId, String code) async {
    await ensureTableExists();
    return (select(promotions)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) &
              tbl.code.isNotNull() &
              tbl.code.equals(code.trim().toUpperCase())))
        .getSingleOrNull();
  }

  Future<List<Promotion>> getActivePromotions(String storeId) async {
    await ensureTableExists();
    return (select(promotions)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) & tbl.active.equals(true))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<void> insertPromotion(PromotionsCompanion promotion) async {
    await ensureTableExists();
    await into(promotions).insert(promotion, mode: InsertMode.insertOrReplace);
  }

  Future<bool> updatePromotion(PromotionsCompanion promotion) async {
    await ensureTableExists();
    return update(promotions).replace(promotion);
  }

  Future<int> deletePromotion(String id) async {
    await ensureTableExists();
    return (delete(promotions)..where((tbl) => tbl.id.equals(id))).go();
  }
}
