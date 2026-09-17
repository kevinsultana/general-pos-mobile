import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transaction_tables.dart';
import '../tables/payment_tables.dart';
import '../tables/refund_tables.dart';
import '../tables/product_tables.dart';
import '../tables/category_tables.dart';
import '../tables/inventory_tables.dart';
import '../../../domain/models/sales_report.dart';
import '../../../domain/models/product_report.dart';
import '../../../domain/models/inventory_report.dart';

part 'report_dao.g.dart';

@DriftAccessor(tables: [
  Transactions,
  TransactionItems,
  Payments,
  PaymentMethods,
  Refunds,
  RefundItems,
  Products,
  Categories,
  StockMovements,
])
class ReportDao extends DatabaseAccessor<AppDatabase> with _$ReportDaoMixin {
  ReportDao(super.db);

  Future<void> healOrphanData(String storeId) async {
    try {
      if (storeId != 'store-default-01' && storeId.isNotEmpty) {
        await customStatement("UPDATE transactions SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
        await customStatement("UPDATE products SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
        await customStatement("UPDATE categories SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
        await customStatement("UPDATE stock_movements SET store_id = '$storeId' WHERE store_id IN ('store-default-01', 'store-default-001', '');");
      }
    } catch (_) {}
  }

  Future<SalesReport> getSalesReport({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await healOrphanData(storeId);

    // 1. Completed Transactions in range
    final completedTrx = await (select(transactions)
          ..where((tbl) =>
              (tbl.storeId.equals(storeId) | tbl.storeId.equals('store-default-01')) &
              tbl.status.equals('COMPLETED') &
              tbl.createdAt.isBiggerOrEqualValue(startDate) &
              tbl.createdAt.isSmallerOrEqualValue(endDate)))
        .get();

    final int grossSales = completedTrx.fold(0, (sum, t) => sum + t.subtotal);
    final int totalDiscounts =
        completedTrx.fold(0, (sum, t) => sum + t.discountTotal);
    final int transactionCount = completedTrx.length;

    // 2. Cancelled Transactions in range
    final cancelledTrx = await (select(transactions)
          ..where((tbl) =>
              (tbl.storeId.equals(storeId) | tbl.storeId.equals('store-default-01')) &
              tbl.status.equals('CANCELLED') &
              tbl.createdAt.isBiggerOrEqualValue(startDate) &
              tbl.createdAt.isSmallerOrEqualValue(endDate)))
        .get();

    final int cancelledCount = cancelledTrx.length;
    final int cancelledTotal =
        cancelledTrx.fold(0, (sum, t) => sum + t.total);

    // 3. Refunds in range (Joined with transactions to ensure storeId matches)
    final refundQuery = select(refunds).join([
      innerJoin(transactions, transactions.id.equalsExp(refunds.transactionId)),
    ])
      ..where(
        (transactions.storeId.equals(storeId) | transactions.storeId.equals('store-default-01')) &
        refunds.createdAt.isBiggerOrEqualValue(startDate) &
        refunds.createdAt.isSmallerOrEqualValue(endDate),
      );

    final refundRows = await refundQuery.get();
    final int refundCount = refundRows.length;
    final int refundTotal = refundRows.fold(
      0,
      (sum, row) => sum + row.readTable(refunds).amount,
    );

    // Net Sales = Gross Sales - Discounts - Refunds
    final int netSales = grossSales - totalDiscounts - refundTotal;

    // 4. Estimated Gross Profit from Transaction Items Snapshot (Cost Snapshot)
    final completedTrxIds = completedTrx.map((t) => t.id).toSet();
    int estimatedGrossProfit = 0;

    if (completedTrxIds.isNotEmpty) {
      final items = await (select(transactionItems)
            ..where((tbl) => tbl.transactionId.isIn(completedTrxIds)))
          .get();

      for (final item in items) {
        final revenue = item.subtotal;
        final cost = (item.quantity * item.unitCostSnapshot).round();
        estimatedGrossProfit += (revenue - cost);
      }
    }

    // Deduct total order discount & refunds from gross profit to get net estimated profit
    estimatedGrossProfit -= totalDiscounts;
    estimatedGrossProfit -= refundTotal;
    if (estimatedGrossProfit < 0) estimatedGrossProfit = 0;

    // 5. Payment Methods Breakdown
    final paymentBreakdownMap = <String, _PaymentAgg>{};

    if (completedTrxIds.isNotEmpty) {
      final paymentRows = await (select(payments)
            ..where((tbl) => tbl.transactionId.isIn(completedTrxIds)))
          .get();

      for (final p in paymentRows) {
        final agg = paymentBreakdownMap.putIfAbsent(
          p.paymentMethodId,
          () => _PaymentAgg(),
        );
        agg.count++;
        agg.totalAmount += p.amount;
      }
    }

    final paymentBreakdown = paymentBreakdownMap.entries.map((e) {
      return PaymentMethodSummary(
        method: e.key,
        count: e.value.count,
        totalAmount: e.value.totalAmount,
      );
    }).toList();

    // 6. Daily Sales Summaries
    final dailyMap = <String, _DailyAgg>{};
    for (final t in completedTrx) {
      final dateKey =
          '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}-${t.createdAt.day.toString().padLeft(2, '0')}';
      final agg = dailyMap.putIfAbsent(
        dateKey,
        () => _DailyAgg(
          DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day),
        ),
      );
      agg.gross += t.subtotal;
      agg.net += (t.subtotal - t.discountTotal);
      agg.count++;
    }

    final dailySummaries = dailyMap.values.map((d) {
      return DailySalesSummary(
        date: d.date,
        grossSales: d.gross,
        netSales: d.net,
        transactionCount: d.count,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return SalesReport(
      startDate: startDate,
      endDate: endDate,
      grossSales: grossSales,
      totalDiscounts: totalDiscounts,
      netSales: netSales,
      estimatedGrossProfit: estimatedGrossProfit,
      transactionCount: transactionCount,
      cancelledCount: cancelledCount,
      cancelledTotal: cancelledTotal,
      refundCount: refundCount,
      refundTotal: refundTotal,
      paymentBreakdown: paymentBreakdown,
      dailySummaries: dailySummaries,
    );
  }

  Future<ProductSalesReport> getProductSalesReport({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await healOrphanData(storeId);
    final completedTrx = await (select(transactions)
          ..where((tbl) =>
              (tbl.storeId.equals(storeId) | tbl.storeId.equals('store-default-01')) &
              tbl.status.equals('COMPLETED') &
              tbl.createdAt.isBiggerOrEqualValue(startDate) &
              tbl.createdAt.isSmallerOrEqualValue(endDate)))
        .get();

    final completedTrxIds = completedTrx.map((t) => t.id).toSet();
    if (completedTrxIds.isEmpty) {
      return ProductSalesReport(
        startDate: startDate,
        endDate: endDate,
        items: const [],
        totalQuantitySold: 0,
        totalRevenue: 0,
        totalCost: 0,
        totalProfit: 0,
      );
    }

    final items = await (select(transactionItems)
          ..where((tbl) => tbl.transactionId.isIn(completedTrxIds)))
        .get();

    final productMap = <String, _ProductAgg>{};

    for (final itm in items) {
      final agg = productMap.putIfAbsent(
        itm.productId,
        () => _ProductAgg(
          productId: itm.productId,
          productName: itm.productNameSnapshot,
        ),
      );
      agg.quantity += itm.quantity;
      agg.revenue += itm.subtotal;
      agg.cost += (itm.quantity * itm.unitCostSnapshot).round();
    }

    // Get category names
    final productIds = productMap.keys.toSet();
    final productEntities = await (select(products)
          ..where((tbl) => tbl.id.isIn(productIds)))
        .get();

    final categoryIds =
        productEntities.map((p) => p.categoryId).toSet();
    final categoryMap = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final categoriesFound = await (select(categories)
            ..where((tbl) => tbl.id.isIn(categoryIds)))
          .get();
      for (final c in categoriesFound) {
        categoryMap[c.id] = c.name;
      }
    }

    final productToCategory = <String, String>{};
    for (final p in productEntities) {
      if (categoryMap.containsKey(p.categoryId)) {
        productToCategory[p.id] = categoryMap[p.categoryId]!;
      }
    }

    final reportItems = productMap.values.map((agg) {
      return ProductReportItem(
        productId: agg.productId,
        productName: agg.productName,
        categoryName: productToCategory[agg.productId],
        quantitySold: agg.quantity,
        revenue: agg.revenue,
        cost: agg.cost,
        grossProfit: agg.revenue - agg.cost,
      );
    }).toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    double totalQty = 0;
    int totalRev = 0;
    int totalCost = 0;
    int totalProfit = 0;

    for (final item in reportItems) {
      totalQty += item.quantitySold;
      totalRev += item.revenue;
      totalCost += item.cost;
      totalProfit += item.grossProfit;
    }

    return ProductSalesReport(
      startDate: startDate,
      endDate: endDate,
      items: reportItems,
      totalQuantitySold: totalQty,
      totalRevenue: totalRev,
      totalCost: totalCost,
      totalProfit: totalProfit,
    );
  }

  Future<InventoryReportSummary> getInventoryReport({
    required String storeId,
  }) async {
    await healOrphanData(storeId);
    final allProducts = await (select(products)
          ..where((tbl) =>
              (tbl.storeId.equals(storeId) | tbl.storeId.equals('store-default-01')) &
              tbl.active.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();

    int totalStockUnits = 0;
    int totalAssetValue = 0;
    final lowStockItems = <StockAlertItem>[];
    final negativeStockItems = <StockAlertItem>[];

    for (final p in allProducts) {
      totalStockUnits += p.stock;
      if (p.stock > 0) {
        totalAssetValue += (p.stock * p.cost);
      }

      final threshold = p.lowStockThreshold > 0 ? p.lowStockThreshold : 5;

      if (p.stock < 0) {
        negativeStockItems.add(
          StockAlertItem(
            productId: p.id,
            productName: p.name,
            stock: p.stock,
            costPrice: p.cost,
            sellingPrice: p.sellingPrice,
            isNegative: true,
          ),
        );
      } else if (p.stock <= threshold) {
        lowStockItems.add(
          StockAlertItem(
            productId: p.id,
            productName: p.name,
            stock: p.stock,
            costPrice: p.cost,
            sellingPrice: p.sellingPrice,
            isNegative: false,
          ),
        );
      }
    }

    // Recent 25 stock movements
    final movements = await (select(stockMovements)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) | tbl.storeId.equals('store-default-01'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(25))
        .get();

    // Map movement product names
    final movProductIds = movements.map((m) => m.productId).toSet();
    final movProducts = await (select(products)
          ..where((tbl) => tbl.id.isIn(movProductIds)))
        .get();
    final productNameMap = {for (final p in movProducts) p.id: p.name};

    final recentMovements = movements.map((m) {
      return MovementSummaryItem(
        id: m.id,
        productId: m.productId,
        productName: productNameMap[m.productId] ?? 'Produk',
        movementType: m.type,
        quantity: m.quantityDelta ~/ 1000,
        createdAt: m.createdAt,
      );
    }).toList();

    return InventoryReportSummary(
      totalProducts: allProducts.length,
      totalStockUnits: totalStockUnits,
      totalAssetValue: totalAssetValue,
      lowStockCount: lowStockItems.length,
      negativeStockCount: negativeStockItems.length,
      lowStockItems: lowStockItems,
      negativeStockItems: negativeStockItems,
      recentMovements: recentMovements,
    );
  }
}

class _PaymentAgg {
  int count = 0;
  int totalAmount = 0;
}

class _DailyAgg {
  final DateTime date;
  int gross = 0;
  int net = 0;
  int count = 0;

  _DailyAgg(this.date);
}

class _ProductAgg {
  final String productId;
  final String productName;
  // DECIMAL(18,3) — fractional quantity
  double quantity = 0;
  int revenue = 0;
  int cost = 0;

  _ProductAgg({required this.productId, required this.productName});
}
