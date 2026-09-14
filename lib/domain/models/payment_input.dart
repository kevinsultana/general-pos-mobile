class PaymentInput {
  final String paymentMethodId;
  final String paymentType; // 'CASH', 'QRIS', 'TRANSFER', 'CARD'
  final int amount; // Amount credited to pay the bill
  final int roundingAmount; // Cash rounding difference (+/-), 0 for non-cash
  final int? tenderedAmount; // Cash handed by customer (e.g. 50000)
  final int? changeAmount; // Change returned to customer
  final String? referenceNumber; // EDC approval code, transfer ref, etc.
  final String? note;

  const PaymentInput({
    required this.paymentMethodId,
    required this.paymentType,
    required this.amount,
    this.roundingAmount = 0,
    this.tenderedAmount,
    this.changeAmount,
    this.referenceNumber,
    this.note,
  });

  /// Total cash received from customer including rounding
  int get totalCashDue => amount + roundingAmount;
}

class RefundItemInput {
  final String transactionItemId;
  final String productId;
  final String? variantId;
  final int quantity; // Number of units refunded
  final int refundAmount; // Amount returned for this item

  const RefundItemInput({
    required this.transactionItemId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.refundAmount,
  });
}
