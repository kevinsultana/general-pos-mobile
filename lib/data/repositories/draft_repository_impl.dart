import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/cart_item.dart';
import '../../domain/repositories/i_draft_repository.dart';
import '../local/app_database.dart';

class DraftRepositoryImpl implements IDraftRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  DraftRepositoryImpl(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
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
  }) async {
    final now = DateTime.now();
    final draftId = existingDraftId ?? _uuid.v4();

    String transactionNumber;
    if (existingDraftId != null) {
      final existing = await _db.transactionDao.getTransactionById(existingDraftId);
      transactionNumber = existing?.transactionNumber ?? _generateDraftNumber(now);
    } else {
      transactionNumber = _generateDraftNumber(now);
    }

    final transactionCompanion = TransactionsCompanion(
      id: Value(draftId),
      storeId: Value(storeId),
      transactionNumber: Value(transactionNumber),
      customerId: Value(customerId),
      status: const Value('DRAFT'),
      orderType: Value(orderType),
      queueNumber: Value(queueNumber),
      subtotal: Value(subtotal),
      discountType: Value(discountType),
      discountValue: Value(discountValue),
      discountTotal: Value(discountTotal),
      roundingAmount: const Value(0),
      total: Value(total),
      paidTotal: const Value(0),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final itemCompanions = items.map((item) {
      return TransactionItemsCompanion(
        id: Value(_uuid.v4()),
        transactionId: Value(draftId),
        productId: Value(item.productId),
        variantId: Value(item.variantId),
        productNameSnapshot: Value(item.productName),
        variantNameSnapshot: Value(item.variantName),
        skuSnapshot: Value(item.sku),
        barcodeSnapshot: Value(item.barcode),
        quantity: Value(item.quantity),
        unitPrice: Value(item.unitPrice),
        unitCostSnapshot: Value(item.unitCostSnapshot),
        discountType: Value(item.discountType),
        discountValue: Value(item.discountValue),
        discountAmount: Value(item.discountAmount),
        subtotal: Value(item.subtotal),
        total: Value(item.total),
        createdAt: Value(now),
      );
    }).toList();

    // Replaces the draft and its items atomically in SQLite.
    // Stock is NOT touched, per PRD rules for drafts.
    await _db.transactionDao.replaceTransactionWithItems(
      transaction: transactionCompanion,
      items: itemCompanions,
    );

    return draftId;
  }

  @override
  Stream<List<Transaction>> watchDrafts(String storeId) {
    return _db.transactionDao.watchDraftTransactions(storeId);
  }

  @override
  Future<List<TransactionItem>> getDraftItems(String transactionId) {
    return _db.transactionDao.getItemsByTransactionId(transactionId);
  }

  @override
  Future<void> deleteDraft(String transactionId) {
    return _db.transactionDao.deleteTransactionWithItems(transactionId);
  }

  String _generateDraftNumber(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final suffix = _uuid.v4().substring(0, 4).toUpperCase();
    return 'DFT-$year$month$day-$suffix';
  }
}
