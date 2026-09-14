import '../../domain/repositories/i_product_repository.dart';
import '../local/app_database.dart';
import '../local/daos/product_dao.dart';
import '../local/daos/category_dao.dart';

class ProductRepositoryImpl implements IProductRepository {
  final ProductDao _productDao;
  final CategoryDao _categoryDao;

  ProductRepositoryImpl(this._productDao, this._categoryDao);

  @override
  Future<List<Product>> getProducts(String storeId) =>
      _productDao.getAllProducts(storeId);

  @override
  Stream<List<Product>> watchProducts(String storeId) =>
      _productDao.watchAllProducts(storeId);

  @override
  Future<Product?> getProductById(String id) =>
      _productDao.getProductById(id);

  @override
  Future<Product?> getProductBySku(String storeId, String sku) =>
      _productDao.getProductBySku(storeId, sku);

  @override
  Future<Product?> getProductByBarcode(String storeId, String barcode) =>
      _productDao.getProductByBarcode(storeId, barcode);

  @override
  Future<void> saveProduct(ProductsCompanion product) =>
      _productDao.insertProduct(product);

  @override
  Future<void> updateStock(String productId, int newStock) =>
      _productDao.updateStock(productId, newStock);

  @override
  Future<List<Category>> getCategories(String storeId) =>
      _categoryDao.getAllCategories(storeId);

  @override
  Stream<List<Category>> watchCategories(String storeId) =>
      _categoryDao.watchAllCategories(storeId);

  @override
  Future<void> saveCategory(CategoriesCompanion category) =>
      _categoryDao.insertCategory(category);

  @override
  Future<int> deleteCategory(String id) =>
      _categoryDao.deleteCategory(id);

  @override
  Future<List<ProductVariant>> getVariants(String productId) =>
      _productDao.getVariantsByProductId(productId);

  @override
  Future<ProductVariant?> getVariantByBarcode(String barcode) =>
      _productDao.getVariantByBarcode(barcode);

  @override
  Future<void> saveVariant(ProductVariantsCompanion variant) =>
      _productDao.insertVariant(variant);
}
