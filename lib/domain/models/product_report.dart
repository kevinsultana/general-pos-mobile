class ProductReportItem {
  final String productId;
  final String productName;
  final String? categoryName;
  // DECIMAL(18,3) — matches TransactionItem.quantity
  final double quantitySold;
  final int revenue;
  final int cost;
  final int grossProfit;

  const ProductReportItem({
    required this.productId,
    required this.productName,
    this.categoryName,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
    required this.grossProfit,
  });

  double get profitMargin =>
      revenue > 0 ? (grossProfit / revenue) * 100 : 0.0;
}

class ProductSalesReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<ProductReportItem> items;
  // DECIMAL(18,3) — sum of all fractional quantities sold
  final double totalQuantitySold;
  final int totalRevenue;
  final int totalCost;
  final int totalProfit;

  const ProductSalesReport({
    required this.startDate,
    required this.endDate,
    required this.items,
    required this.totalQuantitySold,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
  });

  double get overallMargin =>
      totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
}
