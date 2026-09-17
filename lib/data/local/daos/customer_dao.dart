import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/customer_tables.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers])
class CustomerDao extends DatabaseAccessor<AppDatabase> with _$CustomerDaoMixin {
  CustomerDao(super.db);

  Future<void> ensureTableExists() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "customers" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "store_id" TEXT NOT NULL,
        "name" TEXT NOT NULL,
        "phone" TEXT,
        "email" TEXT,
        "notes" TEXT,
        "created_at" INTEGER NOT NULL,
        "updated_at" INTEGER NOT NULL
      );
    ''');
  }

  Future<void> healOrphanCustomers(String storeId) async {
    try {
      if (storeId != 'store-default-01' && storeId.isNotEmpty) {
        await (update(customers)
              ..where((tbl) =>
                  tbl.storeId.equals('store-default-01') |
                  tbl.storeId.equals('store-default-001') |
                  tbl.storeId.equals('')))
            .write(CustomersCompanion(storeId: Value(storeId)));
      }
    } catch (_) {}
  }

  Future<List<Customer>> getAllCustomers(String storeId) async {
    await ensureTableExists();
    await healOrphanCustomers(storeId);
    return (select(customers)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) |
              tbl.storeId.equals('store-default-01'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Stream<List<Customer>> watchAllCustomers(String storeId) async* {
    await ensureTableExists();
    await healOrphanCustomers(storeId);
    yield* (select(customers)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) |
              tbl.storeId.equals('store-default-01'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  Future<List<Customer>> searchCustomers(String storeId, String query) async {
    await ensureTableExists();
    await healOrphanCustomers(storeId);
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(customers)
          ..where((tbl) =>
              (tbl.storeId.equals(storeId) |
                  tbl.storeId.equals('store-default-01')) &
              (tbl.name.lower().like(lowerQuery) |
                  tbl.phone.lower().like(lowerQuery)))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Future<Customer?> getCustomerById(String id) async {
    await ensureTableExists();
    return (select(customers)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertCustomer(CustomersCompanion customer) async {
    await ensureTableExists();
    await into(customers).insert(customer, mode: InsertMode.insertOrReplace);
  }

  Future<bool> updateCustomer(CustomersCompanion customer) async {
    await ensureTableExists();
    return update(customers).replace(customer);
  }

  Future<int> deleteCustomer(String id) async {
    await ensureTableExists();
    return (delete(customers)..where((tbl) => tbl.id.equals(id))).go();
  }
}
