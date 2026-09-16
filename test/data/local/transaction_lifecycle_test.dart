import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';
import 'package:mobile_pos/domain/models/payment_input.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl trxRepo;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    trxRepo = TransactionRepositoryImpl(db);

    // Seed default store
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'store-default-01',
            name: 'Test Coffee POS',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    // Seed product with initial stock = 30
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-latte',
            storeId: 'store-default-01',
            categoryId: 'cat-coffee',
            name: 'Caffe Latte',
            sku: const Value('LAT-001'),
            sellingPrice: 20000,
            cost: 10000,
            stock: 30,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('completeTransaction with Cash & Cash Rounding deducts stock and records SALE ledger',
      () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-latte',
        productName: 'Caffe Latte',
        quantity: 3, // Selling 3 units
        unitPrice: 20000,
        unitCostSnapshot: 10000,
      ),
    ];

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 60000,
        roundingAmount: 500, // Cash rounding
        tenderedAmount: 100000,
        changeAmount: 39500,
      ),
    ];

    final trxId = await trxRepo.completeTransaction(
      storeId: 'store-default-01',
      orderType: 'DINE_IN',
      queueNumber: '#10',
      subtotal: 60000,
      discountTotal: 0,
      roundingAmount: 500,
      total: 60500,
      items: cartItems,
      payments: payments,
    );

    expect(trxId, isNotEmpty);

    // 1. Check Transaction
    final savedTrx = await trxRepo.getTransaction(trxId);
    expect(savedTrx, isNotNull);
    expect(savedTrx!.status, equals('COMPLETED'));
    expect(savedTrx.transactionNumber.startsWith('TRX-'), isTrue);
    expect(savedTrx.total, equals(60500));
    expect(savedTrx.roundingAmount, equals(500));

    // 2. Check Items Snapshot
    final savedItems = await trxRepo.getTransactionItems(trxId);
    expect(savedItems.length, equals(1));
    expect(savedItems.first.quantity, equals(3));
    expect(savedItems.first.unitCostSnapshot, equals(10000));

    // 3. Check Payments
    final savedPayments = await trxRepo.getTransactionPayments(trxId);
    expect(savedPayments.length, equals(1));
    expect(savedPayments.first.amount, equals(60000));
    expect(savedPayments.first.roundingAmount, equals(500));

    // 4. CRITICAL PRD VERIFICATION: Stock must decrease by 3 (30 -> 27)
    final product = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-latte')))
        .getSingle();
    expect(product.stock, equals(27));

    // 5. CRITICAL PRD VERIFICATION: StockMovements ledger row SALE with scale 1000 (-3000)
    final movements = await db.select(db.stockMovements).get();
    expect(movements.length, equals(1));
    expect(movements.first.type, equals('SALE'));
    expect(movements.first.quantityDelta, equals(-3000));
    expect(movements.first.referenceId, equals(trxId));
  });

  test('cancelTransaction performs atomic stock reversal and CANCEL ledger record',
      () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-latte',
        productName: 'Caffe Latte',
        quantity: 5, // Selling 5 units
        unitPrice: 20000,
        unitCostSnapshot: 10000,
      ),
    ];

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-qris',
        paymentType: 'QRIS',
        amount: 100000,
      ),
    ];

    // Complete transaction
    final trxId = await trxRepo.completeTransaction(
      storeId: 'store-default-01',
      orderType: 'TAKEAWAY',
      subtotal: 100000,
      discountTotal: 0,
      roundingAmount: 0,
      total: 100000,
      items: cartItems,
      payments: payments,
    );

    // Verify stock is 25 (30 - 5)
    var prod = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-latte')))
        .getSingle();
    expect(prod.stock, equals(25));

    // Cancel Transaction (Void)
    await trxRepo.cancelTransaction(
      transactionId: trxId,
      reason: 'Pelanggan membatalkan pesanan',
    );

    // 1. Transaction status must be CANCELLED
    final cancelledTrx = await trxRepo.getTransaction(trxId);
    expect(cancelledTrx!.status, equals('CANCELLED'));
    expect(cancelledTrx.cancelledAt, isNotNull);

    // 2. CRITICAL PRD VERIFICATION: Stock must be REVERSED back to 30!
    prod = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-latte')))
        .getSingle();
    expect(prod.stock, equals(30));

    // 3. CRITICAL PRD VERIFICATION: StockMovements must have SALE (-5000) and CANCEL_REVERSAL (+5000)
    final movements = await db.select(db.stockMovements).get();
    expect(movements.length, equals(2));

    final cancelMovement = movements.firstWhere((m) => m.type == 'CANCEL_REVERSAL');
    expect(cancelMovement.quantityDelta, equals(5000));
    expect(cancelMovement.reason, equals('Pelanggan membatalkan pesanan'));
  });

  test('refundTransaction creates refund record, reverses stock, and updates status',
      () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-latte',
        productName: 'Caffe Latte',
        quantity: 4,
        unitPrice: 20000,
        unitCostSnapshot: 10000,
      ),
    ];

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-transfer',
        paymentType: 'TRANSFER',
        amount: 80000,
      ),
    ];

    final trxId = await trxRepo.completeTransaction(
      storeId: 'store-default-01',
      orderType: 'DINE_IN',
      subtotal: 80000,
      discountTotal: 0,
      roundingAmount: 0,
      total: 80000,
      items: cartItems,
      payments: payments,
    );

    final savedItems = await trxRepo.getTransactionItems(trxId);

    // Process partial refund for 2 units
    final refundId = await trxRepo.refundTransaction(
      transactionId: trxId,
      reason: 'Kopi tumpah oleh pramusaji',
      items: [
        RefundItemInput(
          transactionItemId: savedItems.first.id,
          productId: 'prod-latte',
          quantity: 2,
          refundAmount: 40000,
        ),
      ],
      totalRefundAmount: 40000,
    );

    expect(refundId, isNotEmpty);

    // 1. Transaction status must be PARTIALLY_REFUNDED and refundedAt must be set
    final updatedTrx = await trxRepo.getTransaction(trxId);
    expect(updatedTrx!.status, equals('PARTIALLY_REFUNDED'));
    expect(updatedTrx.refundedAt, isNotNull);

    // 2. Stock must be reversed for the 2 refunded units (30 - 4 + 2 = 28)
    final prod = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-latte')))
        .getSingle();
    expect(prod.stock, equals(28));

    // 3. StockMovements must have REFUND_REVERSAL row with +2000
    final movements = await db.select(db.stockMovements).get();
    final refMovement = movements.firstWhere((m) => m.type == 'REFUND_REVERSAL');
    expect(refMovement.quantityDelta, equals(2000));
  });

  test('PRD Bab 21: completeTransaction rejects mismatched roundingAmount', () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-latte',
        productName: 'Caffe Latte',
        quantity: 1,
        unitPrice: 20000,
        unitCostSnapshot: 10000,
      ),
    ];

    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 20000,
        roundingAmount: 200,
      ),
    ];

    expect(
      () => trxRepo.completeTransaction(
        storeId: 'store-default-01',
        orderType: 'DINE_IN',
        subtotal: 20000,
        discountTotal: 0,
        roundingAmount: 500, // MISMATCH: payment has 200, trx has 500
        total: 20500,
        items: cartItems,
        payments: payments,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('PRD Bab 21: Split payment applies cash rounding strictly to CASH component', () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-latte',
        productName: 'Caffe Latte',
        quantity: 1,
        unitPrice: 23500,
        unitCostSnapshot: 10000,
      ),
    ];

    // Total 23.500: Paid 15.000 via QRIS (exact), remaining 8.500 cash rounded with +500 -> 9.000
    final payments = [
      const PaymentInput(
        paymentMethodId: 'pm-qris',
        paymentType: 'QRIS',
        amount: 15000,
        roundingAmount: 0,
      ),
      const PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 8500,
        roundingAmount: 500,
        tenderedAmount: 10000,
        changeAmount: 1000,
      ),
    ];

    final trxId = await trxRepo.completeTransaction(
      storeId: 'store-default-01',
      orderType: 'DINE_IN',
      subtotal: 23500,
      discountTotal: 0,
      roundingAmount: 500,
      total: 24000,
      items: cartItems,
      payments: payments,
    );

    final savedTrx = await trxRepo.getTransaction(trxId);
    expect(savedTrx, isNotNull);
    expect(savedTrx!.roundingAmount, equals(500));
    expect(savedTrx.total, equals(24000));

    final savedPayments = await trxRepo.getTransactionPayments(trxId);
    expect(savedPayments.length, equals(2));
    final qrisPayment = savedPayments.firstWhere((p) => p.paymentMethodId == 'pm-qris');
    final cashPayment = savedPayments.firstWhere((p) => p.paymentMethodId == 'pm-cash');
    expect(qrisPayment.roundingAmount, equals(0));
    expect(cashPayment.roundingAmount, equals(500));
  });
}
