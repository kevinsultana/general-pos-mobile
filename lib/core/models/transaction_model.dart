class TransactionItemModel {
  final String id;
  final String transactionId;
  final String? productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;
  final String? notes;

  TransactionItemModel({
    required this.id,
    required this.transactionId,
    this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
      'notes': notes ?? '',
    };
  }

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      subtotal: (map['subtotal'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class TransactionModel {
  final String id;
  final String tenantId;
  final String? branchId;
  final String? shiftId;
  final String? customerId;
  final String receiptNumber;
  final String? customerName;
  final String? customerPhone;
  final double totalAmount;
  final double discountAmount;
  final String? promoCode;
  final double cashPaid;
  final double changeAmount;
  final String paymentMethod;
  final String syncStatus;
  final String createdAt;
  final List<TransactionItemModel> items;

  TransactionModel({
    required this.id,
    required this.tenantId,
    this.branchId,
    this.shiftId,
    this.customerId,
    required this.receiptNumber,
    this.customerName,
    this.customerPhone,
    required this.totalAmount,
    this.discountAmount = 0,
    this.promoCode,
    required this.cashPaid,
    required this.changeAmount,
    this.paymentMethod = 'CASH',
    this.syncStatus = 'PENDING',
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'shift_id': shiftId,
      'customer_id': customerId,
      'receipt_number': receiptNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'promo_code': promoCode,
      'cash_paid': cashPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'sync_status': syncStatus,
      'created_at': createdAt,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, {List<TransactionItemModel> items = const []}) {
    return TransactionModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      shiftId: map['shift_id'] as String?,
      customerId: map['customer_id'] as String?,
      receiptNumber: map['receipt_number'] as String,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      promoCode: map['promo_code'] as String?,
      cashPaid: (map['cash_paid'] as num).toDouble(),
      changeAmount: (map['change_amount'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? 'CASH',
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING',
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      items: items,
    );
  }
}
