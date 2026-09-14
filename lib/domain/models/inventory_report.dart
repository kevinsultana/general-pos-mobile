class StockAlertItem {
  final String productId;
  final String productName;
  final int stock;
  final int costPrice;
  final int sellingPrice;
  final bool isNegative;

  const StockAlertItem({
    required this.productId,
    required this.productName,
    required this.stock,
    required this.costPrice,
    required this.sellingPrice,
    this.isNegative = false,
  });
}

class MovementSummaryItem {
  final String id;
  final String productId;
  final String productName;
  final String movementType;
  final int quantity;
  final DateTime createdAt;

  const MovementSummaryItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantity,
    required this.createdAt,
  });
}

class InventoryReportSummary {
  final int totalProducts;
  final int totalStockUnits;
  final int totalAssetValue;
  final int lowStockCount;
  final int negativeStockCount;
  final List<StockAlertItem> lowStockItems;
  final List<StockAlertItem> negativeStockItems;
  final List<MovementSummaryItem> recentMovements;

  const InventoryReportSummary({
    required this.totalProducts,
    required this.totalStockUnits,
    required this.totalAssetValue,
    required this.lowStockCount,
    required this.negativeStockCount,
    required this.lowStockItems,
    required this.negativeStockItems,
    required this.recentMovements,
  });
}
