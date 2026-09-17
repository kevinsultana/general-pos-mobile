import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:mobile_pos/data/repositories/store_repository_impl.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_pos/domain/models/payment_input.dart';
import 'package:mobile_pos/presentation/payment/controllers/payment_controller.dart';
import 'package:mobile_pos/presentation/pos/controllers/cart_controller.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl trxRepo;
  late StoreRepositoryImpl storeRepo;
  late ProductRepositoryImpl productRepo;
  late DraftRepositoryImpl draftRepo;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    trxRepo = TransactionRepositoryImpl(db);
    storeRepo = StoreRepositoryImpl(db.storeDao);
    productRepo = ProductRepositoryImpl(db.productDao, db.categoryDao, db: db);
    draftRepo = DraftRepositoryImpl(db);

    // Seed store
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'store-default-01',
            name: 'Test Coffee Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    // Seed product with initial stock = 5
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-americano',
            storeId: 'store-default-01',
            categoryId: 'cat-coffee',
            name: 'Americano',
            sellingPrice: 15000,
            cost: 8000,
            stock: 5,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    // Seed product with variant: Latte Regular (stock 2), Latte Large (stock 10)
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-latte',
            storeId: 'store-default-01',
            categoryId: 'cat-coffee',
            name: 'Latte',
            sellingPrice: 20000,
            cost: 10000,
            stock: 12,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await db.into(db.productVariants).insert(
          ProductVariantsCompanion.insert(
            id: 'var-latte-reg',
            productId: 'prod-latte',
            name: 'Regular',
            sellingPrice: 20000,
            cost: 10000,
            stock: 2,
            active: const Value(true),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    container = ProviderContainer(
      overrides: [
        paymentControllerProvider.overrideWith(
          (ref) => PaymentController(ref, trxRepo, storeRepo, db: db),
        ),
        cartControllerProvider.overrideWith(
          (ref) => CartController(draftRepo, productRepo),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('completePayment throws InsufficientStockException when cart qty exceeds local product stock',
      () async {
    final cartNotifier = container.read(cartControllerProvider.notifier);
    final product = (await db.productDao.getProductById('prod-americano'))!;

    // Cart wants 8 units, but database only has 5 available
    cartNotifier.addProduct(product, quantity: 8);

    final paymentController =
        container.read(paymentControllerProvider.notifier);

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 120000,
        roundingAmount: 0,
        tenderedAmount: 120000,
        changeAmount: 0,
      ),
    ];

    await expectLater(
      paymentController.completePayment(payments: payments),
      throwsA(
        isA<InsufficientStockException>()
            .having((e) => e.productId, 'productId', equals('prod-americano'))
            .having((e) => e.availableStock, 'availableStock', equals(5)),
      ),
    );

    // State of paymentController must be AsyncError
    final paymentState = container.read(paymentControllerProvider);
    expect(paymentState.hasError, isTrue);
    expect(paymentState.error, isA<InsufficientStockException>());

    // CRITICAL: Cart must NOT be cleared on failure
    final cartState = container.read(cartControllerProvider);
    expect(cartState.items, isNotEmpty);
    expect(cartState.items.first.quantity, equals(8));

    // Stock in database must NOT be changed
    final dbProduct = (await db.productDao.getProductById('prod-americano'))!;
    expect(dbProduct.stock, equals(5));
  });

  test('completePayment throws InsufficientStockException when cart qty exceeds variant stock',
      () async {
    final cartNotifier = container.read(cartControllerProvider.notifier);
    final product = (await db.productDao.getProductById('prod-latte'))!;
    final variants = await db.productDao.getVariantsByProductId('prod-latte');
    final regVariant = variants.firstWhere((v) => v.id == 'var-latte-reg');

    // Cart wants 5 regular lattes, but variant stock is only 2
    cartNotifier.addProduct(product, variant: regVariant, quantity: 5);

    final paymentController =
        container.read(paymentControllerProvider.notifier);

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 100000,
        roundingAmount: 0,
        tenderedAmount: 100000,
        changeAmount: 0,
      ),
    ];

    await expectLater(
      paymentController.completePayment(payments: payments),
      throwsA(
        isA<InsufficientStockException>()
            .having((e) => e.productId, 'productId', equals('prod-latte'))
            .having((e) => e.availableStock, 'availableStock', equals(2)),
      ),
    );

    // Cart is preserved
    final cartState = container.read(cartControllerProvider);
    expect(cartState.items, isNotEmpty);
  });

  test('completePayment succeeds when stock is sufficient, clears cart, and updates state',
      () async {
    final cartNotifier = container.read(cartControllerProvider.notifier);
    final product = (await db.productDao.getProductById('prod-americano'))!;

    // Cart wants 3 units, available stock is 5
    cartNotifier.addProduct(product, quantity: 3);

    final paymentController =
        container.read(paymentControllerProvider.notifier);

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 45000,
        roundingAmount: 0,
        tenderedAmount: 50000,
        changeAmount: 5000,
      ),
    ];

    final trxId = await paymentController.completePayment(payments: payments);
    expect(trxId, isNotEmpty);

    // State is AsyncData with transactionId
    final paymentState = container.read(paymentControllerProvider);
    expect(paymentState.value, equals(trxId));

    // Cart is cleared after success
    final cartState = container.read(cartControllerProvider);
    expect(cartState.isEmpty, isTrue);

    // Stock in DB is deducted from 5 to 2
    final dbProduct = (await db.productDao.getProductById('prod-americano'))!;
    expect(dbProduct.stock, equals(2));
  });
}
