import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/customer_repository_impl.dart';

void main() {
  late AppDatabase db;
  late CustomerRepositoryImpl customerRepo;
  const storeId = 'store-test-01';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    customerRepo = CustomerRepositoryImpl(db.customerDao);

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Customer Test Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('Customer CRUD and Search works properly', () async {
    // 1. Create customers
    final cust1Id = await customerRepo.createCustomer(
      storeId: storeId,
      name: 'Budi Santoso',
      phone: '08123456789',
      email: 'budi@gmail.com',
      notes: 'Langganan kopi',
    );

    final cust2Id = await customerRepo.createCustomer(
      storeId: storeId,
      name: 'Siti Aminah',
      phone: '08987654321',
    );

    // 2. Read all
    final all = await customerRepo.getCustomers(storeId);
    expect(all.length, equals(2));
    expect(all.map((c) => c.name), containsAll(['Budi Santoso', 'Siti Aminah']));

    // 3. Search by name
    final searchName = await customerRepo.searchCustomers(storeId, 'budi');
    expect(searchName.length, equals(1));
    expect(searchName.first.id, equals(cust1Id));

    // 4. Search by phone
    final searchPhone = await customerRepo.searchCustomers(storeId, '0898');
    expect(searchPhone.length, equals(1));
    expect(searchPhone.first.id, equals(cust2Id));

    // 5. Update customer
    await customerRepo.updateCustomer(
      id: cust1Id,
      storeId: storeId,
      name: 'Budi Santoso Updated',
      phone: '08123456789',
      email: 'budi_new@gmail.com',
    );

    final updated = await customerRepo.getCustomerById(cust1Id);
    expect(updated?.name, equals('Budi Santoso Updated'));
    expect(updated?.email, equals('budi_new@gmail.com'));

    // 6. Delete customer
    await customerRepo.deleteCustomer(cust2Id);
    final remaining = await customerRepo.getCustomers(storeId);
    expect(remaining.length, equals(1));
    expect(remaining.first.id, equals(cust1Id));
  });
}
