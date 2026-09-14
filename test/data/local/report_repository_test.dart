import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/report_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ReportRepositoryImpl reportRepo;
  const storeId = 'store-test-01';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    reportRepo = ReportRepositoryImpl(db.reportDao);

    final now = DateTime.now();

    // Store
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Report Test Store',
            currency: const Value('IDR'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Categories
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-01',
            storeId: storeId,
            name: 'Makanan & Minuman',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Products
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-01',
            storeId: storeId,
            categoryId: 'cat-01',
            name: 'Kopi Susu Gula Aren',
            cost: 6000,
            sellingPrice: 15000,
            stock: 20,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-02',
            storeId: storeId,
            categoryId: 'cat-01',
            name: 'Roti Bakar Coklat',
            cost: 8000,
            sellingPrice: 20000,
            stock: 3, // Low stock (<= 5)
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-03',
            storeId: storeId,
            categoryId: 'cat-01',
            name: 'Croissant Keju',
            cost: 10000,
            sellingPrice: 25000,
            stock: -2, // Negative stock
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('Sales Report calculates gross, net, discounts, refunds, and cost snapshot profit', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));
    final end = now.add(const Duration(days: 1));

    // 1. Transaction 1: COMPLETED (Kopi x 2, Roti x 1, Discount 5.000, Cash 45.000)
    // Items revenue: (2 * 15.000) + (1 * 20.000) = 50.000
    // Items cost: (2 * 6.000) + (1 * 8.000) = 20.000
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'trx-01',
            storeId: storeId,
            transactionNumber: 'TRX-001',
            status: 'COMPLETED',
            subtotal: 50000,
            discountTotal: const Value(5000),
            total: 45000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'itm-01',
            transactionId: 'trx-01',
            productId: 'prod-01',
            productNameSnapshot: 'Kopi Susu Gula Aren',
            quantity: 2,
            unitPrice: 15000,
            unitCostSnapshot: 6000,
            subtotal: 30000,
            total: 30000,
            createdAt: now,
          ),
        );

    await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'itm-02',
            transactionId: 'trx-01',
            productId: 'prod-02',
            productNameSnapshot: 'Roti Bakar Coklat',
            quantity: 1,
            unitPrice: 20000,
            unitCostSnapshot: 8000,
            subtotal: 20000,
            total: 20000,
            createdAt: now,
          ),
        );

    await db.into(db.payments).insert(
          PaymentsCompanion.insert(
            id: 'pay-01',
            transactionId: 'trx-01',
            paymentMethodId: 'CASH',
            amount: 45000,
            status: 'COMPLETED',
            createdAt: now,
          ),
        );

    // 2. Transaction 2: COMPLETED then REFUNDED (Kopi x 1, subtotal 15.000, QRIS 15.000)
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'trx-02',
            storeId: storeId,
            transactionNumber: 'TRX-002',
            status: 'COMPLETED',
            subtotal: 15000,
            discountTotal: const Value(0),
            total: 15000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'itm-03',
            transactionId: 'trx-02',
            productId: 'prod-01',
            productNameSnapshot: 'Kopi Susu Gula Aren',
            quantity: 1,
            unitPrice: 15000,
            unitCostSnapshot: 6000,
            subtotal: 15000,
            total: 15000,
            createdAt: now,
          ),
        );

    await db.into(db.payments).insert(
          PaymentsCompanion.insert(
            id: 'pay-02',
            transactionId: 'trx-02',
            paymentMethodId: 'QRIS',
            amount: 15000,
            status: 'COMPLETED',
            createdAt: now,
          ),
        );

    // Refund for trx-02
    await db.into(db.refunds).insert(
          RefundsCompanion.insert(
            id: 'ref-01',
            transactionId: 'trx-02',
            amount: 15000,
            reason: 'Salah pesan',
            status: 'COMPLETED',
            createdAt: now,
          ),
        );

    // 3. Transaction 3: CANCELLED (Voided, should not be included in active sales)
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'trx-03',
            storeId: storeId,
            transactionNumber: 'TRX-003',
            status: 'CANCELLED',
            subtotal: 100000,
            discountTotal: const Value(0),
            total: 100000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Generate Sales Report
    final report = await reportRepo.getSalesReport(
      storeId: storeId,
      startDate: start,
      endDate: end,
    );

    // Verification
    expect(report.grossSales, equals(65000)); // 50.000 + 15.000
    expect(report.totalDiscounts, equals(5000));
    expect(report.refundTotal, equals(15000));
    expect(report.refundCount, equals(1));
    expect(report.netSales, equals(45000)); // 65.000 - 5.000 - 15.000
    expect(report.transactionCount, equals(2));
    expect(report.cancelledCount, equals(1));
    expect(report.cancelledTotal, equals(100000));

    // Estimated Profit:
    // Items Gross Profit = (50.000 - 20.000) + (15.000 - 6.000) = 30.000 + 9.000 = 39.000
    // Net Gross Profit = 39.000 - 5.000 (discount) - 15.000 (refund) = 19.000
    expect(report.estimatedGrossProfit, equals(19000));

    // Payment breakdown
    expect(report.paymentBreakdown.length, equals(2));
    final cashPay = report.paymentBreakdown.firstWhere((p) => p.method == 'CASH');
    expect(cashPay.totalAmount, equals(45000));
    final qrisPay = report.paymentBreakdown.firstWhere((p) => p.method == 'QRIS');
    expect(qrisPay.totalAmount, equals(15000));
  });

  test('Product Sales Report ranks best sellers and calculates cost snapshot accurately', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));
    final end = now.add(const Duration(days: 1));

    // Trx 1: 5x Kopi Susu
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'trx-prod-01',
            storeId: storeId,
            transactionNumber: 'TRX-P01',
            status: 'COMPLETED',
            subtotal: 75000,
            total: 75000,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'itm-p-01',
            transactionId: 'trx-prod-01',
            productId: 'prod-01',
            productNameSnapshot: 'Kopi Susu Gula Aren',
            quantity: 5,
            unitPrice: 15000,
            unitCostSnapshot: 6000,
            subtotal: 75000,
            total: 75000,
            createdAt: now,
          ),
        );

    // Trx 2: 2x Roti Bakar
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'trx-prod-02',
            storeId: storeId,
            transactionNumber: 'TRX-P02',
            status: 'COMPLETED',
            subtotal: 40000,
            total: 40000,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'itm-p-02',
            transactionId: 'trx-prod-02',
            productId: 'prod-02',
            productNameSnapshot: 'Roti Bakar Coklat',
            quantity: 2,
            unitPrice: 20000,
            unitCostSnapshot: 8000,
            subtotal: 40000,
            total: 40000,
            createdAt: now,
          ),
        );

    // Even if current product cost changes, historical snapshot cost must be respected!
    await (db.update(db.products)..where((tbl) => tbl.id.equals('prod-01'))).write(
      const ProductsCompanion(cost: Value(99999)),
    );

    final prodReport = await reportRepo.getProductSalesReport(
      storeId: storeId,
      startDate: start,
      endDate: end,
    );

    expect(prodReport.items.length, equals(2));
    // Best seller rank #1: Kopi Susu (5 units)
    expect(prodReport.items[0].productId, equals('prod-01'));
    expect(prodReport.items[0].quantitySold, equals(5));
    expect(prodReport.items[0].revenue, equals(75000));
    expect(prodReport.items[0].cost, equals(30000)); // 5 * 6000 (snapshot!), NOT 99999!
    expect(prodReport.items[0].grossProfit, equals(45000));

    // Rank #2: Roti Bakar (2 units)
    expect(prodReport.items[1].productId, equals('prod-02'));
    expect(prodReport.items[1].quantitySold, equals(2));
    expect(prodReport.items[1].revenue, equals(40000));
    expect(prodReport.items[1].cost, equals(16000)); // 2 * 8000
    expect(prodReport.items[1].grossProfit, equals(24000));
  });

  test('Inventory Report alerts on low stock, negative stock, and total asset valuation', () async {
    final invReport = await reportRepo.getInventoryReport(storeId: storeId);

    expect(invReport.totalProducts, equals(3));
    // prod-01: 20 * 6000 = 120.000
    // prod-02: 3 * 8000 = 24.000
    // prod-03: -2 (negative stock does not add to asset value)
    expect(invReport.totalStockUnits, equals(21)); // 20 + 3 + (-2)
    expect(invReport.totalAssetValue, equals(144000)); // 120.000 + 24.000

    // Low stock: prod-02 (3 units <= 5)
    expect(invReport.lowStockCount, equals(1));
    expect(invReport.lowStockItems.first.productId, equals('prod-02'));

    // Negative stock: prod-03 (-2 units)
    expect(invReport.negativeStockCount, equals(1));
    expect(invReport.negativeStockItems.first.productId, equals('prod-03'));
  });
}
