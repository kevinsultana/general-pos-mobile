import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/customer_repository_impl.dart';
import 'package:mobile_pos/data/repositories/promotion_repository_impl.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';
import 'package:mobile_pos/domain/models/payment_input.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl trxRepo;
  late CustomerRepositoryImpl customerRepo;
  late PromotionRepositoryImpl promoRepo;
  const storeId = 'store-test-01';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    trxRepo = TransactionRepositoryImpl(db);
    customerRepo = CustomerRepositoryImpl(db.customerDao);
    promoRepo = PromotionRepositoryImpl(db.promotionDao);

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Customer Trx Test Store',
            currency: const Value('IDR'),
            customerEnabled: const Value(true),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-01',
            storeId: storeId,
            categoryId: 'cat-01',
            name: 'Kopi Susu Spesial',
            sellingPrice: 20000,
            cost: 8000,
            stock: 50,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('Transaction completed with customer and promotion records IDs properly',
      () async {
    // 1. Create a customer
    final customerId = await customerRepo.createCustomer(
      storeId: storeId,
      name: 'Andi Pratama',
      phone: '081122334455',
    );

    // 2. Create a promotion
    final promoId = await promoRepo.createPromotion(
      storeId: storeId,
      name: 'Diskon Merdeka',
      code: 'MERDEKA5K',
      discountType: 'FIXED',
      discountValue: 5000,
    );

    // 3. Complete transaction with customerId and promotionId
    final cartItem = CartItem(
      productId: 'prod-01',
      productName: 'Kopi Susu Spesial',
      quantity: 2,
      unitPrice: 20000,
      unitCostSnapshot: 8000,
    );

    const subtotal = 40000;
    const discountTotal = 5000;
    const finalTotal = 35000;

    final trxId = await trxRepo.completeTransaction(
      storeId: storeId,
      orderType: 'DINE_IN',
      queueNumber: '#01',
      customerId: customerId,
      promotionId: promoId,
      subtotal: subtotal,
      discountType: 'FIXED',
      discountValue: 5000,
      discountTotal: discountTotal,
      roundingAmount: 0,
      total: finalTotal,
      items: [cartItem],
      payments: [
        const PaymentInput(
          paymentMethodId: 'pm-cash-01',
          paymentType: 'CASH',
          amount: 35000,
          tenderedAmount: 50000,
          changeAmount: 15000,
        ),
      ],
    );

    // 4. Verify transaction row in DB
    final savedTrx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(trxId)))
        .getSingle();

    expect(savedTrx.status, equals('COMPLETED'));
    expect(savedTrx.customerId, equals(customerId));
    expect(savedTrx.promotionId, equals(promoId));
    expect(savedTrx.total, equals(finalTotal));
    expect(savedTrx.discountTotal, equals(discountTotal));

    // Verify stock deducted
    final updatedProduct = await (db.select(db.products)
          ..where((p) => p.id.equals('prod-01')))
        .getSingle();
    expect(updatedProduct.stock, equals(48)); // 50 - 2
  });
}
