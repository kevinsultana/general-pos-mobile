import '../../data/local/app_database.dart';

abstract class IProductRepository {
  Future<List<Product>> getProducts(String storeId);
  Stream<List<Product>> watchProducts(String storeId);
  Future<Product?> getProductById(String id);
  Future<Product?> getProductBySku(String storeId, String sku);
  Future<Product?> getProductByBarcode(String storeId, String barcode);
  Future<void> saveProduct(ProductsCompanion product);
  Future<void> updateStock(String productId, int newStock);

  // Categories
  Future<List<Category>> getCategories(String storeId);
  Stream<List<Category>> watchCategories(String storeId);
  Future<void> saveCategory(CategoriesCompanion category);
  Future<int> deleteCategory(String id);

  // Variants
  Future<List<ProductVariant>> getVariants(String productId);
  Future<ProductVariant?> getVariantByBarcode(String barcode);
  Future<void> saveVariant(ProductVariantsCompanion variant);
}
