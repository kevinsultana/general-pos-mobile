import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/product_tables.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products, ProductVariants])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  Future<List<Product>> getAllProducts(String storeId) {
    return (select(products)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.active.equals(true)))
        .get();
  }

  Stream<List<Product>> watchAllProducts(String storeId) {
    return (select(products)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.active.equals(true)))
        .watch();
  }

  Future<Product?> getProductById(String id) {
    return (select(products)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<Product?> getProductBySku(String storeId, String sku) {
    return (select(products)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.sku.equals(sku)))
        .getSingleOrNull();
  }

  Future<Product?> getProductByBarcode(String storeId, String barcode) {
    return (select(products)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  Future<void> insertProduct(ProductsCompanion product) {
    return into(products).insert(product, mode: InsertMode.insertOrReplace);
  }

  Future<bool> updateProduct(ProductsCompanion product) {
    return update(products).replace(product);
  }

  Future<void> updateStock(String productId, int newStock) {
    return (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        stock: Value(newStock),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Variants
  Future<List<ProductVariant>> getVariantsByProductId(String productId) {
    return (select(productVariants)
          ..where((tbl) => tbl.productId.equals(productId) & tbl.active.equals(true)))
        .get();
  }

  Future<void> insertVariant(ProductVariantsCompanion variant) {
    return into(productVariants).insert(variant, mode: InsertMode.insertOrReplace);
  }

  Future<ProductVariant?> getVariantByBarcode(String barcode) {
    return (select(productVariants)
          ..where((tbl) => tbl.barcode.equals(barcode) & tbl.active.equals(true)))
        .getSingleOrNull();
  }

  Future<int> deleteProduct(String id) async {
    await (delete(productVariants)..where((tbl) => tbl.productId.equals(id))).go();
    return (delete(products)..where((tbl) => tbl.id.equals(id))).go();
  }
}
