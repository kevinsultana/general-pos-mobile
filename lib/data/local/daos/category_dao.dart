import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/category_tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<List<Category>> getAllCategories(String storeId) {
    return (select(categories)..where((tbl) => tbl.storeId.equals(storeId))).get();
  }

  Stream<List<Category>> watchAllCategories(String storeId) {
    return (select(categories)..where((tbl) => tbl.storeId.equals(storeId))).watch();
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
