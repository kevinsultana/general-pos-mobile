import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/i_product_repository.dart';
import '../local/app_database.dart';
import '../local/daos/product_dao.dart';
import '../local/daos/category_dao.dart';
import '../services/api_client.dart';

class ProductRepositoryImpl implements IProductRepository {
  final ProductDao _productDao;
  final CategoryDao _categoryDao;
  final AppDatabase? _db;
  final bool _isCloudMode;
  final String? _deviceId;
  final ApiClient? _apiClient;

  ProductRepositoryImpl(
    this._productDao,
    this._categoryDao, {
    this._db,
    this._isCloudMode = false,
    this._deviceId,
    ApiClient? apiClient,
  }) : _apiClient = apiClient;

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
  Future<void> saveProduct(
    ProductsCompanion product, {
    List<ProductVariantsCompanion>? variants,
  }) async {
    await _productDao.insertProduct(product);

    if (variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        await _productDao.insertVariant(v);
      }
    }

    if (_isCloudMode && _db != null && product.id.present && product.storeId.present) {
      final fetchedVariants = await _productDao.getVariantsByProductId(product.id.value);
      final variantsList = (variants != null && variants.isNotEmpty)
          ? variants
              .map((v) => {
                    'id': v.id.value,
                    'name': v.name.value,
                    'sku': v.sku.present ? v.sku.value : null,
                    'barcode': v.barcode.present ? v.barcode.value : null,
                    'cost': v.cost.present ? v.cost.value : 0,
                    'sellingPrice': v.sellingPrice.present ? v.sellingPrice.value : 0,
                    'stock': v.stock.present ? v.stock.value : 0,
                    'lowStockThreshold':
                        v.lowStockThreshold.present ? v.lowStockThreshold.value : 5,
                    'active': v.active.present ? v.active.value : true,
                  })
              .toList()
          : fetchedVariants
              .map((v) => {
                    'id': v.id,
                    'name': v.name,
                    'sku': v.sku,
                    'barcode': v.barcode,
                    'cost': v.cost,
                    'sellingPrice': v.sellingPrice,
                    'stock': v.stock,
                    'lowStockThreshold': v.lowStockThreshold,
                    'active': v.active,
                  })
              .toList();

      final payload = {
        'id': product.id.value,
        'name': product.name.value,
        'sku': product.sku.present ? product.sku.value : null,
        'barcode': product.barcode.present ? product.barcode.value : null,
        'categoryId': product.categoryId.present ? product.categoryId.value : null,
        'cost': product.cost.present ? product.cost.value : 0,
        'sellingPrice': product.sellingPrice.present ? product.sellingPrice.value : 0,
        'stock': product.stock.present ? product.stock.value : 0,
        'lowStockThreshold':
            product.lowStockThreshold.present ? product.lowStockThreshold.value : 5,
        'active': product.active.present ? product.active.value : true,
        'discontinued':
            product.discontinued.present ? product.discontinued.value : false,
        'variants': variantsList,
      };

      bool pushedOnline = false;
      if (_apiClient != null) {
        try {
          await _apiClient!.post('/api/v1/products', payload);
          pushedOnline = true;
        } catch (_) {
          pushedOnline = false;
        }
      }

      if (!pushedOnline) {
        await _db!.syncEventDao.insertRawEvent(
          id: const Uuid().v4(),
          storeId: product.storeId.value,
          deviceId: _deviceId ?? 'pos-device',
          entityType: 'Product',
          entityId: product.id.value,
          operation: 'CREATE_PRODUCT',
          payload: jsonEncode(payload),
          status: 'PENDING',
          createdAt: product.createdAt.present ? product.createdAt.value : DateTime.now(),
        );
      }
    }
  }

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
  Future<void> saveCategory(CategoriesCompanion category) async {
    await _categoryDao.insertCategory(category);
    if (_isCloudMode && _db != null && category.id.present && category.storeId.present) {
      final payload = {
        'id': category.id.value,
        'name': category.name.value,
        'active': true,
      };

      bool pushedOnline = false;
      if (_apiClient != null) {
        try {
          await _apiClient!.post('/api/v1/categories', payload);
          pushedOnline = true;
        } catch (_) {
          pushedOnline = false;
        }
      }

      if (!pushedOnline) {
        await _db!.syncEventDao.insertRawEvent(
          id: const Uuid().v4(),
          storeId: category.storeId.value,
          deviceId: _deviceId ?? 'pos-device',
          entityType: 'Category',
          entityId: category.id.value,
          operation: 'CREATE_CATEGORY',
          payload: jsonEncode(payload),
          status: 'PENDING',
          createdAt: category.createdAt.present ? category.createdAt.value : DateTime.now(),
        );
      }
    }
  }

  @override
  Future<int> deleteCategory(String id) async {
    final existing = await _categoryDao.getCategoryById(id);
    final count = await _categoryDao.deleteCategory(id);
    if (_isCloudMode && _db != null && existing != null) {
      bool pushedOnline = false;
      if (_apiClient != null) {
        try {
          await _apiClient!.delete('/api/v1/categories/$id');
          pushedOnline = true;
        } catch (_) {
          pushedOnline = false;
        }
      }

      if (!pushedOnline) {
        await _db!.syncEventDao.insertRawEvent(
          id: const Uuid().v4(),
          storeId: existing.storeId,
          deviceId: _deviceId ?? 'pos-device',
          entityType: 'Category',
          entityId: id,
          operation: 'DELETE_CATEGORY',
          payload: jsonEncode({
            'id': id,
          }),
          status: 'PENDING',
          createdAt: DateTime.now(),
        );
      }
    }
    return count;
  }

  @override
  Future<List<ProductVariant>> getVariants(String productId) =>
      _productDao.getVariantsByProductId(productId);

  @override
  Stream<List<ProductVariant>> watchVariants(String productId) =>
      _productDao.watchVariantsByProductId(productId);

  @override
  Future<ProductVariant?> getVariantByBarcode(String barcode) =>
      _productDao.getVariantByBarcode(barcode);

  @override
  Future<void> saveVariant(ProductVariantsCompanion variant) async {
    await _productDao.insertVariant(variant);
    if (_isCloudMode && _db != null && variant.productId.present) {
      final product = await _productDao.getProductById(variant.productId.value);
      if (product != null) {
        final variants = await _productDao.getVariantsByProductId(product.id);
        final payload = {
          'id': product.id,
          'name': product.name,
          'sku': product.sku,
          'barcode': product.barcode,
          'categoryId': product.categoryId,
          'cost': product.cost,
          'sellingPrice': product.sellingPrice,
          'stock': product.stock,
          'lowStockThreshold': product.lowStockThreshold,
          'active': product.active,
          'discontinued': product.discontinued,
          'variants': variants
              .map((v) => {
                    'id': v.id,
                    'name': v.name,
                    'sku': v.sku,
                    'barcode': v.barcode,
                    'cost': v.cost,
                    'sellingPrice': v.sellingPrice,
                    'stock': v.stock,
                    'lowStockThreshold': v.lowStockThreshold,
                    'active': v.active,
                  })
              .toList(),
        };

        bool pushedOnline = false;
        if (_apiClient != null) {
          try {
            await _apiClient!.put('/api/v1/products/${product.id}', payload);
            pushedOnline = true;
          } catch (_) {
            pushedOnline = false;
          }
        }

        if (!pushedOnline) {
          await _db!.syncEventDao.insertRawEvent(
            id: const Uuid().v4(),
            storeId: product.storeId,
            deviceId: _deviceId ?? 'pos-device',
            entityType: 'Product',
            entityId: product.id,
            operation: 'UPDATE_PRODUCT',
            payload: jsonEncode(payload),
            status: 'PENDING',
            createdAt: DateTime.now(),
          );
        }
      }
    }
  }

  @override
  Future<void> reconcileVariantStocks() =>
      _productDao.reconcileVariantStocks();
}
