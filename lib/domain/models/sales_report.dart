class PaymentMethodSummary {
  final String method;
  final int count;
  final int totalAmount;

  const PaymentMethodSummary({
    required this.method,
    required this.count,
    required this.totalAmount,
  });
}

class DailySalesSummary {
  final DateTime date;
  final int grossSales;
  final int netSales;
  final int transactionCount;

  const DailySalesSummary({
    required this.date,
    required this.grossSales,
    required this.netSales,
    required this.transactionCount,
  });
}

class SalesReport {
  final DateTime startDate;
  final DateTime endDate;
  final int grossSales;
  final int totalDiscounts;
  final int netSales;
  final int estimatedGrossProfit;
  final int transactionCount;
  final int cancelledCount;
  final int cancelledTotal;
  final int refundCount;
  final int refundTotal;
  final List<PaymentMethodSummary> paymentBreakdown;
  final List<DailySalesSummary> dailySummaries;

  const SalesReport({
    required this.startDate,
    required this.endDate,
    required this.grossSales,
    required this.totalDiscounts,
    required this.netSales,
    required this.estimatedGrossProfit,
    required this.transactionCount,
    required this.cancelledCount,
    required this.cancelledTotal,
    required this.refundCount,
    required this.refundTotal,
    required this.paymentBreakdown,
    required this.dailySummaries,
  });

  int get averageTransactionValue =>
      transactionCount > 0 ? (netSales ~/ transactionCount) : 0;

  double get profitMargin =>
      netSales > 0 ? (estimatedGrossProfit / netSales) * 100 : 0.0;
}
