class CartItem {
  final String productId;
  final String? variantId;
  final String productName;
  final String? variantName;
  final String? sku;
  final String? barcode;
  final int quantity;
  final int unitPrice;
  final int unitCostSnapshot;
  final String? discountType; // 'PERCENTAGE' or 'FIXED_AMOUNT'
  final int? discountValue; // percentage (e.g., 10 for 10%) or nominal amount (e.g., 5000)

  const CartItem({
    required this.productId,
    this.variantId,
    required this.productName,
    this.variantName,
    this.sku,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.unitCostSnapshot,
    this.discountType,
    this.discountValue,
  });

  String get uniqueKey =>
      variantId != null && variantId!.isNotEmpty ? '$productId:$variantId' : productId;

  String get displayName => variantName != null && variantName!.isNotEmpty
      ? '$productName - $variantName'
      : productName;

  /// Subtotal before line discount (quantity * unitPrice)
  int get subtotal => quantity * unitPrice;

  /// Line discount amount in Rupiah (clamped to not exceed subtotal)
  int get discountAmount {
    if (discountType == null || discountValue == null || discountValue! <= 0) {
      return 0;
    }
    if (discountType == 'PERCENTAGE') {
      final calculated = (subtotal * discountValue! / 100).round();
      return calculated > subtotal ? subtotal : calculated;
    } else if (discountType == 'FIXED' || discountType == 'FIXED_AMOUNT') {
      return discountValue! > subtotal ? subtotal : discountValue!;
    }
    return 0;
  }

  /// Total after line discount
  int get total => subtotal - discountAmount;

  /// Total cost (quantity * unitCostSnapshot)
  int get costTotal => quantity * unitCostSnapshot;

  /// Gross profit (total revenue - total cost)
  int get grossProfit => total - costTotal;

  CartItem copyWith({
    String? productId,
    String? variantId,
    String? productName,
    String? variantName,
    String? sku,
    String? barcode,
    int? quantity,
    int? unitPrice,
    int? unitCostSnapshot,
    String? discountType,
    int? discountValue,
    bool clearDiscount = false,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      variantName: variantName ?? this.variantName,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCostSnapshot: unitCostSnapshot ?? this.unitCostSnapshot,
      discountType: clearDiscount ? null : (discountType ?? this.discountType),
      discountValue: clearDiscount ? null : (discountValue ?? this.discountValue),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          uniqueKey == other.uniqueKey &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          unitCostSnapshot == other.unitCostSnapshot &&
          discountType == other.discountType &&
          discountValue == other.discountValue;

  @override
  int get hashCode =>
      uniqueKey.hashCode ^
      quantity.hashCode ^
      unitPrice.hashCode ^
      unitCostSnapshot.hashCode ^
      discountType.hashCode ^
      discountValue.hashCode;
}
