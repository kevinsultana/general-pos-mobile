class PromotionModel {
  final String id;
  final String tenantId;
  final String name;
  final String code;
  final String discountType; // 'PERCENTAGE' or 'FIXED'
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final bool isActive;
  final String syncStatus;

  PromotionModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount = 0,
    this.maxDiscountAmount,
    this.isActive = true,
    this.syncStatus = 'PENDING',
  });

  double calculateDiscount(double subtotal) {
    if (subtotal < minOrderAmount) return 0;

    double discount = 0;
    if (discountType == 'PERCENTAGE') {
      discount = subtotal * (discountValue / 100);
      if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
        if (discount > maxDiscountAmount!) discount = maxDiscountAmount!;
      }
    } else {
      discount = discountValue;
    }

    if (discount > subtotal) discount = subtotal;
    return discount;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'code': code.toUpperCase(),
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus,
    };
  }

  factory PromotionModel.fromMap(Map<String, dynamic> map) {
    return PromotionModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      code: (map['code'] as String).toUpperCase(),
      discountType: (map['discount_type'] as String?) ?? 'FIXED',
      discountValue: (map['discount_value'] as num).toDouble(),
      minOrderAmount: (map['min_order_amount'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount: (map['max_discount_amount'] as num?)?.toDouble(),
      isActive: (map['is_active'] as int?) == 1,
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING',
    );
  }
}
