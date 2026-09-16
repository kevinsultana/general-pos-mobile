import 'dart:math' as math;
import '../models/cart_item.dart';

class TransactionCalculationResult {
  final int rawSubtotal; // Sum of all items before any discounts
  final int itemDiscountsTotal; // Sum of all line item discounts
  final int orderSubtotal; // Subtotal after line discounts, before order discount
  final int orderDiscountAmount; // Order-level discount amount
  final int grandTotal; // Final payable amount
  final int totalCost; // Total cost (COGS) based on unitCostSnapshot
  final int grossProfit; // grandTotal - totalCost
  // DECIMAL(18,3) — total physical quantity (sum of all item quantities, may be fractional)
  final double totalItemCount;

  const TransactionCalculationResult({
    required this.rawSubtotal,
    required this.itemDiscountsTotal,
    required this.orderSubtotal,
    required this.orderDiscountAmount,
    required this.grandTotal,
    required this.totalCost,
    required this.grossProfit,
    required this.totalItemCount,
  });
}

class TransactionCalculator {
  const TransactionCalculator();

  /// Calculates a discount amount given a subtotal, type ('PERCENTAGE' or 'FIXED'), and value.
  /// Always returns a non-negative integer and never exceeds the [subtotal].
  int calculateDiscount({
    required int subtotal,
    required String? discountType,
    required int? discountValue,
  }) {
    if (subtotal <= 0 ||
        discountType == null ||
        discountValue == null ||
        discountValue <= 0) {
      return 0;
    }

    if (discountType == 'PERCENTAGE') {
      final calculated = (subtotal * discountValue / 100).round();
      return math.min(subtotal, math.max(0, calculated));
    } else if (discountType == 'FIXED' || discountType == 'FIXED_AMOUNT') {
      return math.min(subtotal, math.max(0, discountValue));
    }

    return 0;
  }

  /// Calculates a single authoritative transaction summary from the list of cart items
  /// and the order-level discount.
  TransactionCalculationResult calculate({
    required List<CartItem> items,
    String? orderDiscountType,
    int? orderDiscountValue,
  }) {
    int rawSubtotal = 0;
    int itemDiscountsTotal = 0;
    int orderSubtotal = 0;
    int totalCost = 0;
    double totalItemCount = 0;

    for (final item in items) {
      rawSubtotal += item.subtotal;
      itemDiscountsTotal += item.discountAmount;
      orderSubtotal += item.total;
      totalCost += item.costTotal;
      totalItemCount += item.quantity;
    }

    final orderDiscountAmount = calculateDiscount(
      subtotal: orderSubtotal,
      discountType: orderDiscountType,
      discountValue: orderDiscountValue,
    );

    final grandTotal = math.max(0, orderSubtotal - orderDiscountAmount);
    final grossProfit = grandTotal - totalCost;

    return TransactionCalculationResult(
      rawSubtotal: rawSubtotal,
      itemDiscountsTotal: itemDiscountsTotal,
      orderSubtotal: orderSubtotal,
      orderDiscountAmount: orderDiscountAmount,
      grandTotal: grandTotal,
      totalCost: totalCost,
      grossProfit: grossProfit,
      totalItemCount: totalItemCount,
    );
  }
}
