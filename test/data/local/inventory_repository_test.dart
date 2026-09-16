import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/inventory_repository_impl.dart';
import 'package:mobile_pos/data/repositories/product_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl productRepo;
  late InventoryRepositoryImpl inventoryRepo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    productRepo = ProductRepositoryImpl(db.productDao, db.categoryDao);
    inventoryRepo = InventoryRepositoryImpl(db, db.productDao, db.stockMovementDao);
  });

  tearDown(() async {
    await db.close();
  });

  test('Stock In updates stock, recalculates weighted average cost, and records movement', () async {
    const storeId = 'store-test-01';
    const categoryId = 'cat-coffee';
    const productId = 'prod-kopi-01';
    final now = DateTime.now();

    // 1. Setup initial product with 10 units @ Rp5.000 (HPP)
    await productRepo.saveCategory(
      CategoriesCompanion(
        id: const Value(categoryId),
        storeId: const Value(storeId),
        name: const Value('Kopi'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await productRepo.saveProduct(
      ProductsCompanion(
        id: const Value(productId),
        storeId: const Value(storeId),
        categoryId: const Value(categoryId),
        name: const Value('Kopi Gula Aren'),
        cost: const Value(5000),
        sellingPrice: const Value(12000),
        stock: const Value(10), // 10 units initial
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // 2. Perform Stock In: +20 units @ Rp6.000
    // Expected Weighted Average Cost: (10*5000 + 20*6000) / 30 = 5667
    // Expected Stock: 10 + 20 = 30
    await inventoryRepo.stockIn(
      storeId: storeId,
      productId: productId,
      addedQty: 20,
      unitCost: 6000,
      reason: 'Purchase Batch 2',
    );

    final updatedProduct = await productRepo.getProductById(productId);
    expect(updatedProduct, isNotNull);
    expect(updatedProduct!.stock, equals(30));
    expect(updatedProduct.cost, equals(5667));

    // 3. Verify stock movement entry
    final movements = await inventoryRepo.getProductStockMovements(productId);
    expect(movements.length, equals(1));
    expect(movements.first.type, equals('STOCK_IN'));
    expect(movements.first.quantityDelta, equals(20000)); // 20 units * 1000 scale
    expect(movements.first.unitCost, equals(6000));
    expect(movements.first.reason, equals('Purchase Batch 2'));

    // 4. Perform Stock Adjustment: -5 units (Damaged)
    await inventoryRepo.stockAdjustment(
      storeId: storeId,
      productId: productId,
      deltaQty: -5,
      reason: 'Barang Rusak',
    );

    final adjustedProduct = await productRepo.getProductById(productId);
    expect(adjustedProduct!.stock, equals(25)); // 30 - 5 = 25

    final allMovements = await inventoryRepo.getProductStockMovements(productId);
    expect(allMovements.length, equals(2));
    expect(allMovements.any((m) => m.type == 'ADJUSTMENT' && m.quantityDelta == -5000), isTrue);
    expect(allMovements.any((m) => m.type == 'STOCK_IN' && m.quantityDelta == 20000), isTrue);
  });
}
