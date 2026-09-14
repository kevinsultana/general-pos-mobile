import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/payment_tables.dart';

part 'payment_dao.g.dart';

@DriftAccessor(tables: [Payments, PaymentMethods])
class PaymentDao extends DatabaseAccessor<AppDatabase> with _$PaymentDaoMixin {
  PaymentDao(super.db);

  Future<void> insertPayment(PaymentsCompanion payment) {
    return into(payments).insert(payment, mode: InsertMode.insertOrReplace);
  }

  Future<List<Payment>> getPaymentsByTransactionId(String transactionId) {
    return (select(payments)
          ..where((tbl) => tbl.transactionId.equals(transactionId)))
        .get();
  }

  Future<List<PaymentMethod>> getActivePaymentMethods(String storeId) {
    return (select(paymentMethods)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.enabled.equals(true)))
        .get();
  }

  Future<void> insertPaymentMethod(PaymentMethodsCompanion method) {
    return into(paymentMethods).insert(method, mode: InsertMode.insertOrReplace);
  }
}
