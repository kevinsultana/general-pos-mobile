import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transaction_tables.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions, TransactionItems])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<void> saveTransactionWithItems({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
  }) {
    return db.transaction(() async {
      await into(transactions).insert(transaction, mode: InsertMode.insertOrReplace);
      for (final item in items) {
        await into(transactionItems).insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<Transaction?> getTransactionById(String id) {
    return (select(transactions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<TransactionItem>> getItemsByTransactionId(String transactionId) {
    return (select(transactionItems)
          ..where((tbl) => tbl.transactionId.equals(transactionId)))
        .get();
  }

  Future<List<Transaction>> getTransactionsByStore(String storeId, {int limit = 50}) {
    return (select(transactions)
          ..where((tbl) => tbl.storeId.equals(storeId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<Transaction>> watchTransactionsByStore(String storeId, {int limit = 50}) {
    return (select(transactions)
          ..where((tbl) => tbl.storeId.equals(storeId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> updateTransactionStatus(String transactionId, String status) {
    return (update(transactions)..where((tbl) => tbl.id.equals(transactionId))).write(
      TransactionsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateTransactionRefunded(
    String transactionId,
    String status,
    DateTime refundedAt,
  ) {
    return (update(transactions)..where((tbl) => tbl.id.equals(transactionId))).write(
      TransactionsCompanion(
        status: Value(status),
        refundedAt: Value(refundedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> replaceTransactionWithItems({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
  }) {
    return db.transaction(() async {
      final trxId = transaction.id.value;
      await (delete(transactionItems)
            ..where((tbl) => tbl.transactionId.equals(trxId)))
          .go();
      await into(transactions).insert(transaction, mode: InsertMode.insertOrReplace);
      for (final item in items) {
        await into(transactionItems).insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Stream<List<Transaction>> watchDraftTransactions(String storeId) {
    return (select(transactions)
          ..where((tbl) =>
              (tbl.storeId.equals(storeId) | tbl.storeId.equals('default-store')) &
              tbl.status.equals('DRAFT'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Future<void> deleteTransactionWithItems(String transactionId) {
    return db.transaction(() async {
      await (delete(transactionItems)
            ..where((tbl) => tbl.transactionId.equals(transactionId)))
          .go();
      await (delete(transactions)
            ..where((tbl) => tbl.id.equals(transactionId)))
          .go();
    });
  }
}
