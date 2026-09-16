import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/domain/models/app_enums.dart';

void main() {
  group('P1.2 Enum Harmonization Tests', () {
    test('DiscountType serialization and fallback mapping', () {
      expect(DiscountType.percentage.toDbString(), equals('PERCENTAGE'));
      expect(DiscountType.fixedAmount.toDbString(), equals('FIXED_AMOUNT'));

      expect(DiscountType.fromString('PERCENTAGE'), equals(DiscountType.percentage));
      expect(DiscountType.fromString('FIXED_AMOUNT'), equals(DiscountType.fixedAmount));
      expect(DiscountType.fromString('FIXED'), equals(DiscountType.fixedAmount));
      expect(DiscountType.fromString(null), equals(DiscountType.percentage));
    });

    test('TransactionStatus serialization and parsing', () {
      expect(TransactionStatus.draft.toDbString(), equals('DRAFT'));
      expect(TransactionStatus.completed.toDbString(), equals('COMPLETED'));
      expect(TransactionStatus.cancelled.toDbString(), equals('CANCELLED'));
      expect(TransactionStatus.partiallyRefunded.toDbString(), equals('PARTIALLY_REFUNDED'));
      expect(TransactionStatus.refunded.toDbString(), equals('REFUNDED'));

      expect(TransactionStatus.fromString('DRAFT'), equals(TransactionStatus.draft));
      expect(TransactionStatus.fromString('COMPLETED'), equals(TransactionStatus.completed));
      expect(TransactionStatus.fromString('CANCELLED'), equals(TransactionStatus.cancelled));
      expect(TransactionStatus.fromString('PARTIALLY_REFUNDED'), equals(TransactionStatus.partiallyRefunded));
      expect(TransactionStatus.fromString('REFUNDED'), equals(TransactionStatus.refunded));
      expect(TransactionStatus.fromString(null), equals(TransactionStatus.draft));
    });

    test('PaymentStatus serialization and legacy mapping', () {
      expect(PaymentStatus.pending.toDbString(), equals('PENDING'));
      expect(PaymentStatus.completed.toDbString(), equals('COMPLETED'));
      expect(PaymentStatus.voided.toDbString(), equals('VOIDED'));

      expect(PaymentStatus.fromString('PENDING'), equals(PaymentStatus.pending));
      expect(PaymentStatus.fromString('COMPLETED'), equals(PaymentStatus.completed));
      expect(PaymentStatus.fromString('VOIDED'), equals(PaymentStatus.voided));
      expect(PaymentStatus.fromString('FAILED'), equals(PaymentStatus.voided));
      expect(PaymentStatus.fromString('REFUNDED'), equals(PaymentStatus.voided));
      expect(PaymentStatus.fromString(null), equals(PaymentStatus.pending));
    });

    test('RefundStatus serialization and legacy mapping', () {
      expect(RefundStatus.completed.toDbString(), equals('COMPLETED'));
      expect(RefundStatus.voided.toDbString(), equals('VOIDED'));

      expect(RefundStatus.fromString('COMPLETED'), equals(RefundStatus.completed));
      expect(RefundStatus.fromString('VOIDED'), equals(RefundStatus.voided));
      expect(RefundStatus.fromString('CANCELLED'), equals(RefundStatus.voided));
      expect(RefundStatus.fromString(null), equals(RefundStatus.completed));
    });

    test('OrderType serialization and parsing', () {
      expect(OrderType.dineIn.toDbString(), equals('DINE_IN'));
      expect(OrderType.takeaway.toDbString(), equals('TAKEAWAY'));

      expect(OrderType.fromString('DINE_IN'), equals(OrderType.dineIn));
      expect(OrderType.fromString('TAKEAWAY'), equals(OrderType.takeaway));
      expect(OrderType.fromString('TAKE_AWAY'), equals(OrderType.takeaway));
      expect(OrderType.fromString(null), equals(OrderType.dineIn));
    });

    test('StockMovementType serialization and legacy mapping', () {
      expect(StockMovementType.initial.toDbString(), equals('INITIAL'));
      expect(StockMovementType.stockIn.toDbString(), equals('STOCK_IN'));
      expect(StockMovementType.sale.toDbString(), equals('SALE'));
      expect(StockMovementType.adjustment.toDbString(), equals('ADJUSTMENT'));
      expect(StockMovementType.cancelReversal.toDbString(), equals('CANCEL_REVERSAL'));
      expect(StockMovementType.refundReversal.toDbString(), equals('REFUND_REVERSAL'));

      expect(StockMovementType.fromString('INITIAL'), equals(StockMovementType.initial));
      expect(StockMovementType.fromString('STOCK_IN'), equals(StockMovementType.stockIn));
      expect(StockMovementType.fromString('IN'), equals(StockMovementType.stockIn));
      expect(StockMovementType.fromString('SALE'), equals(StockMovementType.sale));
      expect(StockMovementType.fromString('ADJUSTMENT'), equals(StockMovementType.adjustment));
      expect(StockMovementType.fromString('CANCEL_REVERSAL'), equals(StockMovementType.cancelReversal));
      expect(StockMovementType.fromString('CANCEL'), equals(StockMovementType.cancelReversal));
      expect(StockMovementType.fromString('REFUND_REVERSAL'), equals(StockMovementType.refundReversal));
      expect(StockMovementType.fromString('REFUND'), equals(StockMovementType.refundReversal));
    });
  });
}
