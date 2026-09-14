import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/product_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl productRepo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    productRepo = ProductRepositoryImpl(db.productDao, db.categoryDao);
  });

  tearDown(() async {
    await db.close();
  });

  test('Category & Product CRUD with ProductRepository', () async {
    const storeId = 'store-test-01';
    const categoryId = 'cat-beverages';
    final now = DateTime.now();

    // 1. Insert Category
    await productRepo.saveCategory(
      CategoriesCompanion(
        id: const Value(categoryId),
        storeId: const Value(storeId),
        name: const Value('Minuman'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final categories = await productRepo.getCategories(storeId);
    expect(categories.length, equals(1));
    expect(categories.first.name, equals('Minuman'));

    // 2. Insert Product
    const productId = 'prod-kopi-susu';
    await productRepo.saveProduct(
      ProductsCompanion(
        id: const Value(productId),
        storeId: const Value(storeId),
        categoryId: const Value(categoryId),
        name: const Value('Kopi Susu Gula Aren'),
        sku: const Value('KS-001'),
        barcode: const Value('8991234567890'),
        cost: const Value(7000),
        sellingPrice: const Value(15000),
        stock: const Value(50),
        lowStockThreshold: const Value(5),
        active: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final product = await productRepo.getProductById(productId);
    expect(product, isNotNull);
    expect(product!.name, equals('Kopi Susu Gula Aren'));
    expect(product.sku, equals('KS-001'));
    expect(product.cost, equals(7000));
    expect(product.sellingPrice, equals(15000));
    expect(product.stock, equals(50));

    // Lookup by SKU & Barcode
    final bySku = await productRepo.getProductBySku(storeId, 'KS-001');
    expect(bySku?.id, equals(productId));

    final byBarcode = await productRepo.getProductByBarcode(storeId, '8991234567890');
    expect(byBarcode?.id, equals(productId));

    // 3. Insert Variant
    const variantId = 'var-large';
    await productRepo.saveVariant(
      ProductVariantsCompanion(
        id: const Value(variantId),
        productId: const Value(productId),
        name: const Value('Large (500ml)'),
        sku: const Value('KS-001-LG'),
        cost: const Value(9000),
        sellingPrice: const Value(18000),
        stock: const Value(20),
        active: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final variants = await productRepo.getVariants(productId);
    expect(variants.length, equals(1));
    expect(variants.first.name, equals('Large (500ml)'));
    expect(variants.first.sellingPrice, equals(18000));
  });
}
