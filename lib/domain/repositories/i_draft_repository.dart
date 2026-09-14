import '../../data/local/app_database.dart';
import '../models/cart_item.dart';

abstract class IDraftRepository {
  /// Saves a cart as a DRAFT transaction without affecting stock.
  /// If [existingDraftId] is provided, it replaces/updates that draft.
  /// Returns the transactionId of the saved draft.
  Future<String> saveDraft({
    String? existingDraftId,
    required String storeId,
    required String orderType,
    String? queueNumber,
    String? customerId,
    String? discountType,
    int? discountValue,
    required int subtotal,
    required int discountTotal,
    required int total,
    required List<CartItem> items,
  });

  /// Real-time stream of all DRAFT transactions for a store
  Stream<List<Transaction>> watchDrafts(String storeId);

  /// Retrieves all transaction items for a specific draft
  Future<List<TransactionItem>> getDraftItems(String transactionId);

  /// Deletes a draft and its items without affecting stock
  Future<void> deleteDraft(String transactionId);
}
