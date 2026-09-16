import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/inventory_repository_impl.dart';
import 'package:mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';
import 'package:mobile_pos/domain/models/payment_input.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl productRepo;
  late InventoryRepositoryImpl inventoryRepo;
  late TransactionRepositoryImpl transactionRepo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    productRepo = ProductRepositoryImpl(db.productDao, db.categoryDao);
    inventoryRepo = InventoryRepositoryImpl(db, db.productDao, db.stockMovementDao);
    transactionRepo = TransactionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Variant inventory stock-in, adjustment, sale deduction and reconcile work consistently', () async {
    const storeId = 'store-test-01';
    const categoryId = 'cat-coffee';
    const productId = 'prod-kopi-susu';
    const variantIdReg = 'var-kopi-regular';
    const variantIdLrg = 'var-kopi-large';
    final now = DateTime.now();

    // 1. Setup category & product "Kopi Susu" with 2 variants
    await productRepo.saveCategory(
      CategoriesCompanion(
        id: const Value(categoryId),
        storeId: const Value(storeId),
        name: const Value('Minuman'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Initial product has master stock = 30 (10 regular + 20 large)
    await productRepo.saveProduct(
      ProductsCompanion(
        id: const Value(productId),
        storeId: const Value(storeId),
        categoryId: const Value(categoryId),
        name: const Value('Kopi Susu'),
        cost: const Value(8000),
        sellingPrice: const Value(15000),
        stock: const Value(30),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await productRepo.saveVariant(
      ProductVariantsCompanion(
        id: const Value(variantIdReg),
        productId: const Value(productId),
        name: const Value('Regular'),
        cost: const Value(8000),
        sellingPrice: const Value(15000),
        stock: const Value(10),
        active: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await productRepo.saveVariant(
      ProductVariantsCompanion(
        id: const Value(variantIdLrg),
        productId: const Value(productId),
        name: const Value('Large'),
        cost: const Value(10000),
        sellingPrice: const Value(18000),
        stock: const Value(20),
        active: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Verify initial state
    var p = await productRepo.getProductById(productId);
    var vars = await productRepo.getVariants(productId);
    expect(p!.stock, equals(30));
    expect(vars.firstWhere((v) => v.id == variantIdReg).stock, equals(10));
    expect(vars.firstWhere((v) => v.id == variantIdLrg).stock, equals(20));

    // 2. Stock In: Add +15 to Regular variant
    await inventoryRepo.stockIn(
      storeId: storeId,
      productId: productId,
      variantId: variantIdReg,
      addedQty: 15,
      unitCost: 8000,
      reason: 'Beli bahan Regular',
    );

    p = await productRepo.getProductById(productId);
    vars = await productRepo.getVariants(productId);
    expect(vars.firstWhere((v) => v.id == variantIdReg).stock, equals(25)); // 10 + 15 = 25
    expect(vars.firstWhere((v) => v.id == variantIdLrg).stock, equals(20)); // unchanged
    expect(p!.stock, equals(45)); // 25 + 20 = 45

    // 3. Stock Adjustment: Deduct -5 from Large variant (spill/waste)
    await inventoryRepo.stockAdjustment(
      storeId: storeId,
      productId: productId,
      variantId: variantIdLrg,
      deltaQty: -5,
      reason: 'Tumpah',
    );

    p = await productRepo.getProductById(productId);
    vars = await productRepo.getVariants(productId);
    expect(vars.firstWhere((v) => v.id == variantIdLrg).stock, equals(15)); // 20 - 5 = 15
    expect(p!.stock, equals(40)); // 25 + 15 = 40

    // 4. POS Sale: Customer buys 3 Regular variants
    final trxId = await transactionRepo.completeTransaction(
      storeId: storeId,
      orderType: 'DINE_IN',
      subtotal: 45000,
      discountTotal: 0,
      roundingAmount: 0,
      total: 45000,
      items: [
        const CartItem(
          productId: productId,
          variantId: variantIdReg,
          productName: 'Kopi Susu',
          variantName: 'Regular',
          quantity: 3,
          unitPrice: 15000,
          unitCostSnapshot: 8000,
        ),
      ],
      payments: [
        const PaymentInput(
          paymentMethodId: 'pm-cash',
          paymentType: 'CASH',
          amount: 45000,
        ),
      ],
    );

    expect(trxId, isNotEmpty);

    p = await productRepo.getProductById(productId);
    vars = await productRepo.getVariants(productId);
    expect(vars.firstWhere((v) => v.id == variantIdReg).stock, equals(22)); // 25 - 3 = 22
    expect(p!.stock, equals(37)); // 22 + 15 = 37 (never minus!)

    // 5. Test Cancel Transaction Reversal
    await transactionRepo.cancelTransaction(
      transactionId: trxId,
      reason: 'Customer salah pesan',
    );

    p = await productRepo.getProductById(productId);
    vars = await productRepo.getVariants(productId);
    expect(vars.firstWhere((v) => v.id == variantIdReg).stock, equals(25)); // 22 + 3 restored = 25
    expect(p!.stock, equals(40)); // 25 + 15 = 40

    // 6. Test Auto-reconcile desync healing
    // Simulate a buggy state where variant stock was -1 and master was 50 for a single-variant item
    const singleProdId = 'prod-single-var';
    const singleVarId = 'var-single-var';
    await productRepo.saveProduct(
      ProductsCompanion(
        id: const Value(singleProdId),
        storeId: const Value(storeId),
        categoryId: const Value(categoryId),
        name: const Value('Single Var Coffee'),
        cost: const Value(5000),
        sellingPrice: const Value(10000),
        stock: const Value(50), // master shows 50
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await productRepo.saveVariant(
      ProductVariantsCompanion(
        id: const Value(singleVarId),
        productId: const Value(singleProdId),
        name: const Value('Default'),
        cost: const Value(5000),
        sellingPrice: const Value(10000),
        stock: const Value(-1), // variant became -1
        active: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Run auto-heal reconcile
    await productRepo.reconcileVariantStocks();

    final healedSingleVar = (await productRepo.getVariants(singleProdId)).first;
    final healedSingleProd = await productRepo.getProductById(singleProdId);
    expect(healedSingleVar.stock, equals(50)); // Healed from master stock
    expect(healedSingleProd!.stock, equals(50));
  });
}
