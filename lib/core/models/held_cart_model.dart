class HeldCartModel {
  final String id;
  final String tenantId;
  final String label;
  final String cartJson;
  final String? customerName;
  final double totalAmount;
  final int totalItems;
  final String createdAt;

  HeldCartModel({
    required this.id,
    required this.tenantId,
    required this.label,
    required this.cartJson,
    this.customerName,
    required this.totalAmount,
    required this.totalItems,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'label': label,
      'cart_json': cartJson,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'total_items': totalItems,
      'created_at': createdAt,
    };
  }

  factory HeldCartModel.fromMap(Map<String, dynamic> map) {
    return HeldCartModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      label: map['label'] as String,
      cartJson: map['cart_json'] as String,
      customerName: map['customer_name'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalItems: (map['total_items'] as num).toInt(),
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}
