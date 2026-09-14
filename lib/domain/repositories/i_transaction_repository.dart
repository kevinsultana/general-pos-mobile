import '../../data/local/app_database.dart';
import '../models/cart_item.dart';
import '../models/payment_input.dart';

abstract class ITransactionRepository {
  /// Atomically completes a transaction:
  /// 1. Inserts Transaction with status 'COMPLETED' and generated transactionNumber (TRX-...)
  /// 2. Inserts TransactionItems with price & cost snapshots
  /// 3. Inserts Payments records
  /// 4. Deducts product/variant stock
  /// 5. Records StockMovements ledger rows (type: 'SALE', quantityDelta: -quantity * 1000)
  /// 6. Deletes old draft if this transaction originated from a draft
  /// Returns the transactionId.
  Future<String> completeTransaction({
    required String storeId,
    required String orderType,
    String? queueNumber,
    String? customerId,
    String? promotionId,
    required int subtotal,
    String? discountType,
    int? discountValue,
    required int discountTotal,
    required int roundingAmount,
    required int total,
    required List<CartItem> items,
    required List<PaymentInput> payments,
    String? draftId,
  });

  /// Atomically cancels a completed transaction:
  /// 1. Updates transaction status to 'CANCELLED' with cancelledAt and reason
  /// 2. Reverses product/variant stock
  /// 3. Records StockMovements ledger rows (type: 'CANCEL', quantityDelta: +quantity * 1000)
  Future<void> cancelTransaction({
    required String transactionId,
    required String reason,
  });

  /// Atomically processes a refund:
  /// 1. Inserts Refunds and RefundItems records
  /// 2. Reverses product/variant stock for the refunded items
  /// 3. Records StockMovements ledger rows (type: 'REFUND', quantityDelta: +quantity * 1000)
  /// 4. Updates transaction status to 'PARTIALLY_REFUNDED' or 'REFUNDED'
  Future<String> refundTransaction({
    required String transactionId,
    required String reason,
    required List<RefundItemInput> items,
    required int totalRefundAmount,
  });

  Future<void> createTransaction({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
    PaymentsCompanion? payment,
  });

  /// Real-time stream of recent transactions for a store
  Stream<List<Transaction>> watchTransactions(String storeId, {int limit = 50});

  Future<Transaction?> getTransaction(String id);
  Future<List<TransactionItem>> getTransactionItems(String transactionId);
  Future<List<Payment>> getTransactionPayments(String transactionId);
  Future<List<Refund>> getTransactionRefunds(String transactionId);
  Future<List<RefundItem>> getRefundItems(String refundId);
}
