import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
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

  /// Formats store prefix (e.g. 'store-default-01' -> 'DEFA', 'store-01' -> 'S01', 'STR1' -> 'STR1')
  String formatStorePrefix(String storeId) {
    var clean = storeId.toUpperCase().replaceAll('STORE-', '').replaceAll('STORE', '');
    clean = clean.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty) {
      clean = storeId.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    }
    if (clean.isEmpty) clean = 'STR';
    return clean.length > 4 ? clean.substring(0, 4) : clean.padRight(3, '0');
  }

  /// Formats device prefix or short UUID (e.g. 'POS-01' -> 'POS01', 'DEV1' -> 'DEV1', UUID -> 'E2A5')
  String formatDevicePrefix(String? deviceId) {
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      final clean = deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      if (clean.isNotEmpty) {
        if (clean.length <= 5) return clean;
        return clean.substring(0, 4);
      }
    }
    return const Uuid().v4().replaceAll('-', '').substring(0, 4).toUpperCase();
  }

  /// Formats timestamp in compact YYYYMMDD format for clean thermal printing
  String formatTimestamp(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  /// Counts transactions for a specific store on a specific date to generate counter
  Future<int> getTransactionCountForDate(String storeId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final countExpr = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([countExpr])
      ..where(
        transactions.storeId.equals(storeId) &
        transactions.createdAt.isBiggerOrEqualValue(startOfDay) &
        transactions.createdAt.isSmallerThanValue(endOfDay),
      );

    final row = await query.getSingleOrNull();
    final count = row?.read(countExpr) ?? 0;
    return count;
  }

  /// Generates an offline conflict-resistant transaction number
  /// Format: TRX-{STORE_ID_PREFIX}-{DEVICE_ID_OR_SHORT_UUID}-{TIMESTAMP}-{COUNTER}
  Future<String> generateTransactionNumber({
    required String storeId,
    String? deviceId,
    DateTime? date,
    int? counter,
  }) async {
    final now = date ?? DateTime.now();
    final storePrefix = formatStorePrefix(storeId);
    final devicePrefix = formatDevicePrefix(deviceId);
    final timestamp = formatTimestamp(now);
    final count = counter ?? ((await getTransactionCountForDate(storeId, now)) + 1);
    final counterStr = count.toString().padLeft(4, '0');

    return 'TRX-$storePrefix-$devicePrefix-$timestamp-$counterStr';
  }
}
