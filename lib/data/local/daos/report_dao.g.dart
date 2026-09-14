// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_dao.dart';

// ignore_for_file: type=lint
mixin _$ReportDaoMixin on DatabaseAccessor<AppDatabase> {
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $TransactionItemsTable get transactionItems =>
      attachedDatabase.transactionItems;
  $PaymentsTable get payments => attachedDatabase.payments;
  $PaymentMethodsTable get paymentMethods => attachedDatabase.paymentMethods;
  $RefundsTable get refunds => attachedDatabase.refunds;
  $RefundItemsTable get refundItems => attachedDatabase.refundItems;
  $ProductsTable get products => attachedDatabase.products;
  $CategoriesTable get categories => attachedDatabase.categories;
  $StockMovementsTable get stockMovements => attachedDatabase.stockMovements;
  ReportDaoManager get managers => ReportDaoManager(this);
}

class ReportDaoManager {
  final _$ReportDaoMixin _db;
  ReportDaoManager(this._db);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$TransactionItemsTableTableManager get transactionItems =>
      $$TransactionItemsTableTableManager(
        _db.attachedDatabase,
        _db.transactionItems,
      );
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
  $$PaymentMethodsTableTableManager get paymentMethods =>
      $$PaymentMethodsTableTableManager(
        _db.attachedDatabase,
        _db.paymentMethods,
      );
  $$RefundsTableTableManager get refunds =>
      $$RefundsTableTableManager(_db.attachedDatabase, _db.refunds);
  $$RefundItemsTableTableManager get refundItems =>
      $$RefundItemsTableTableManager(_db.attachedDatabase, _db.refundItems);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(
        _db.attachedDatabase,
        _db.stockMovements,
      );
}
