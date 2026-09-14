class CostCalculator {
  const CostCalculator._();

  /// Calculates the new Weighted Average Cost (HPP Rata-Rata Tertimbang)
  /// according to PRD Section 11:
  ///
  /// New Cost = ((Existing Qty * Existing Cost) + (Added Qty * Added Cost)) / (Existing Qty + Added Qty)
  ///
  /// Special handling:
  /// - If existingQty <= 0, the new cost is set directly to addedCost.
  /// - If addedQty <= 0, returns existingCost.
  static int calculateWeightedAverageCost({
    required int existingQty,
    required int existingCost,
    required int addedQty,
    required int addedCost,
  }) {
    if (addedQty <= 0) return existingCost;
    if (existingQty <= 0) return addedCost;

    final totalExistingValue = existingQty * existingCost;
    final totalAddedValue = addedQty * addedCost;
    final totalQty = existingQty + addedQty;

    if (totalQty <= 0) return addedCost;

    return ((totalExistingValue + totalAddedValue) / totalQty).round();
  }
}
