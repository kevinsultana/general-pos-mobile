import '../../data/local/app_database.dart';

abstract class IInventoryRepository {
  /// Executes a Stock In operation:
  /// 1. Updates product stock (stock += addedQty)
  /// 2. Recalculates and updates product cost (HPP) using Weighted Average Cost
  /// 3. Records a stock movement ledger entry with scale 1000
  Future<void> stockIn({
    required String storeId,
    required String productId,
    String? variantId,
    required int addedQty,
    required int unitCost,
    String? reason,
  });

  /// Executes a Stock Adjustment operation (manual increase or decrease):
  /// 1. Updates product stock (stock += deltaQty, can be positive or negative)
  /// 2. Records a stock movement ledger entry with reason (Damaged, Lost, Expired, Opname, Correction)
  Future<void> stockAdjustment({
    required String storeId,
    required String productId,
    String? variantId,
    required int deltaQty,
    required String reason,
  });

  /// Retrieves the chronological stock movement ledger for a product
  Future<List<StockMovement>> getProductStockMovements(String productId);
}
