import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/category_tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<void> healOrphanCategories(String storeId) async {
    try {
      if (storeId != 'store-default-01' && storeId.isNotEmpty) {
        await (update(categories)
              ..where((tbl) =>
                  tbl.storeId.equals('store-default-01') |
                  tbl.storeId.equals('store-default-001') |
                  tbl.storeId.equals('')))
            .write(CategoriesCompanion(storeId: Value(storeId)));
      }
    } catch (_) {}
  }

  Future<List<Category>> getAllCategories(String storeId) async {
    await healOrphanCategories(storeId);
    return (select(categories)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) |
              tbl.storeId.equals('store-default-01')))
        .get();
  }

  Stream<List<Category>> watchAllCategories(String storeId) async* {
    await healOrphanCategories(storeId);
    yield* (select(categories)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) |
              tbl.storeId.equals('store-default-01')))
        .watch();
  }

  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertCategory(CategoriesCompanion category) {
    return into(categories).insert(category, mode: InsertMode.insertOrReplace);
  }

  Future<int> deleteCategory(String id) {
    return (delete(categories)..where((tbl) => tbl.id.equals(id))).go();
  }
}
