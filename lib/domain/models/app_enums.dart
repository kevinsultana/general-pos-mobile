library;

export 'printer_device.dart'
    show PrinterRole, PrinterPaperSize, PrinterConnectionType, PrinterState;
export 'promotion_ext.dart';

/// Types of discount applied to cart items, promotions, or orders.
enum DiscountType {
  percentage,
  fixedAmount;

  static DiscountType fromString(String? value) {
    if (value == null) return DiscountType.percentage;
    switch (value.trim().toUpperCase()) {
      case 'FIXED':
      case 'FIXED_AMOUNT':
        return DiscountType.fixedAmount;
      case 'PERCENTAGE':
      default:
        return DiscountType.percentage;
    }
  }

  String toDbString() {
    switch (this) {
      case DiscountType.percentage:
        return 'PERCENTAGE';
      case DiscountType.fixedAmount:
        return 'FIXED_AMOUNT';
    }
  }

  String get displayName {
    switch (this) {
      case DiscountType.percentage:
        return 'Persentase (%)';
      case DiscountType.fixedAmount:
        return 'Nominal (Rp)';
    }
  }
}

/// Lifecycle status of a sales transaction.
enum TransactionStatus {
  draft,
  completed,
  cancelled,
  partiallyRefunded,
  refunded;

  static TransactionStatus fromString(String? value) {
    if (value == null) return TransactionStatus.draft;
    switch (value.trim().toUpperCase()) {
      case 'COMPLETED':
        return TransactionStatus.completed;
      case 'CANCELLED':
        return TransactionStatus.cancelled;
      case 'PARTIALLY_REFUNDED':
        return TransactionStatus.partiallyRefunded;
      case 'REFUNDED':
        return TransactionStatus.refunded;
      case 'DRAFT':
      default:
        return TransactionStatus.draft;
    }
  }

  String toDbString() {
    switch (this) {
      case TransactionStatus.draft:
        return 'DRAFT';
      case TransactionStatus.completed:
        return 'COMPLETED';
      case TransactionStatus.cancelled:
        return 'CANCELLED';
      case TransactionStatus.partiallyRefunded:
        return 'PARTIALLY_REFUNDED';
      case TransactionStatus.refunded:
        return 'REFUNDED';
    }
  }

  String get displayName {
    switch (this) {
      case TransactionStatus.draft:
        return 'Draft';
      case TransactionStatus.completed:
        return 'Selesai';
      case TransactionStatus.cancelled:
        return 'Dibatalkan';
      case TransactionStatus.partiallyRefunded:
        return 'Sebagian Refund';
      case TransactionStatus.refunded:
        return 'Refund Penuh';
    }
  }
}

/// Status of an individual payment attempt or record.
enum PaymentStatus {
  pending,
  completed,
  voided;

  static PaymentStatus fromString(String? value) {
    if (value == null) return PaymentStatus.pending;
    switch (value.trim().toUpperCase()) {
      case 'COMPLETED':
        return PaymentStatus.completed;
      case 'VOIDED':
      case 'FAILED':
      case 'REFUNDED':
        return PaymentStatus.voided;
      case 'PENDING':
      default:
        return PaymentStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case PaymentStatus.pending:
        return 'PENDING';
      case PaymentStatus.completed:
        return 'COMPLETED';
      case PaymentStatus.voided:
        return 'VOIDED';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Menunggu';
      case PaymentStatus.completed:
        return 'Berhasil';
      case PaymentStatus.voided:
        return 'Dibatalkan';
    }
  }
}

/// Status of a processed refund.
enum RefundStatus {
  completed,
  voided;

  static RefundStatus fromString(String? value) {
    if (value == null) return RefundStatus.completed;
    switch (value.trim().toUpperCase()) {
      case 'VOIDED':
      case 'CANCELLED':
        return RefundStatus.voided;
      case 'COMPLETED':
      default:
        return RefundStatus.completed;
    }
  }

  String toDbString() {
    switch (this) {
      case RefundStatus.completed:
        return 'COMPLETED';
      case RefundStatus.voided:
        return 'VOIDED';
    }
  }

  String get displayName {
    switch (this) {
      case RefundStatus.completed:
        return 'Berhasil';
      case RefundStatus.voided:
        return 'Dibatalkan';
    }
  }
}

/// Fulfillment / serving type of an order.
enum OrderType {
  dineIn,
  takeaway;

  static OrderType fromString(String? value) {
    if (value == null) return OrderType.dineIn;
    switch (value.trim().toUpperCase()) {
      case 'TAKEAWAY':
      case 'TAKE_AWAY':
        return OrderType.takeaway;
      case 'DINE_IN':
      default:
        return OrderType.dineIn;
    }
  }

  String toDbString() {
    switch (this) {
      case OrderType.dineIn:
        return 'DINE_IN';
      case OrderType.takeaway:
        return 'TAKEAWAY';
    }
  }

  String get displayName {
    switch (this) {
      case OrderType.dineIn:
        return 'Dine In';
      case OrderType.takeaway:
        return 'Takeaway';
    }
  }
}

/// Movement type recorded in the inventory ledger.
enum StockMovementType {
  initial,
  stockIn,
  sale,
  adjustment,
  cancelReversal,
  refundReversal;

  static StockMovementType fromString(String? value) {
    if (value == null) return StockMovementType.adjustment;
    switch (value.trim().toUpperCase()) {
      case 'INITIAL':
        return StockMovementType.initial;
      case 'STOCK_IN':
      case 'IN':
        return StockMovementType.stockIn;
      case 'SALE':
        return StockMovementType.sale;
      case 'ADJUSTMENT':
        return StockMovementType.adjustment;
      case 'CANCEL_REVERSAL':
      case 'CANCEL':
        return StockMovementType.cancelReversal;
      case 'REFUND_REVERSAL':
      case 'REFUND':
        return StockMovementType.refundReversal;
      default:
        return StockMovementType.adjustment;
    }
  }

  String toDbString() {
    switch (this) {
      case StockMovementType.initial:
        return 'INITIAL';
      case StockMovementType.stockIn:
        return 'STOCK_IN';
      case StockMovementType.sale:
        return 'SALE';
      case StockMovementType.adjustment:
        return 'ADJUSTMENT';
      case StockMovementType.cancelReversal:
        return 'CANCEL_REVERSAL';
      case StockMovementType.refundReversal:
        return 'REFUND_REVERSAL';
    }
  }

  String get displayName {
    switch (this) {
      case StockMovementType.initial:
        return 'Stok Awal';
      case StockMovementType.stockIn:
        return 'Stok Masuk';
      case StockMovementType.sale:
        return 'Penjualan';
      case StockMovementType.adjustment:
        return 'Penyesuaian';
      case StockMovementType.cancelReversal:
        return 'Batal Transaksi';
      case StockMovementType.refundReversal:
        return 'Refund';
    }
  }
}
