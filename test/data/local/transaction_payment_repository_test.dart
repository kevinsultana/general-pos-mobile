import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl transactionRepo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    transactionRepo = TransactionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Save complete transaction with items, cash payment, and rounding amount', () async {
    const storeId = 'store-test-01';
    const trxId = 'trx-001';
    final now = DateTime.now();

    // Setup transaction with Rp9.997 rounded to Rp10.000 (+3)
    await transactionRepo.createTransaction(
      transaction: TransactionsCompanion(
        id: const Value(trxId),
        storeId: const Value(storeId),
        transactionNumber: const Value('TRX-20260913-0001'),
        status: const Value('COMPLETED'),
        subtotal: const Value(9997),
        discountTotal: const Value(0),
        roundingAmount: const Value(3), // +3 rounding adjustment
        total: const Value(10000), // Rounded Total
        paidTotal: const Value(10000),
        createdAt: Value(now),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
      items: [
        TransactionItemsCompanion(
          id: const Value('item-001'),
          transactionId: const Value(trxId),
          productId: const Value('prod-001'),
          productNameSnapshot: const Value('Kopi Susu Gula Aren'),
          quantity: const Value(1), // 1 unit (raw, no scaling)
          unitPrice: const Value(9997),
          unitCostSnapshot: const Value(5000), // Historical Cost snapshot
          subtotal: const Value(9997),
          total: const Value(9997),
          createdAt: Value(now),
        ),
      ],
      payment: PaymentsCompanion(
        id: const Value('pay-001'),
        transactionId: const Value(trxId),
        paymentMethodId: const Value('method-cash'),
        amount: const Value(10000),
        roundingAmount: const Value(3),
        status: const Value('COMPLETED'),
        paidAt: Value(now),
        createdAt: Value(now),
      ),
    );

    final trx = await transactionRepo.getTransaction(trxId);
    expect(trx, isNotNull);
    expect(trx!.transactionNumber, equals('TRX-20260913-0001'));
    expect(trx.subtotal, equals(9997));
    expect(trx.roundingAmount, equals(3));
    expect(trx.total, equals(10000));
    expect(trx.status, equals('COMPLETED'));

    final items = await transactionRepo.getTransactionItems(trxId);
    expect(items.length, equals(1));
    expect(items.first.productNameSnapshot, equals('Kopi Susu Gula Aren'));
    expect(items.first.unitCostSnapshot, equals(5000));

    final payments = await db.paymentDao.getPaymentsByTransactionId(trxId);
    expect(payments.length, equals(1));
    expect(payments.first.amount, equals(10000));
    expect(payments.first.roundingAmount, equals(3));
  });
}
