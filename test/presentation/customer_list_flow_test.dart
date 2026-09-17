import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/constants/app_constants.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/customers/screens/customer_list_screen.dart';

void main() {
  late AppDatabase db;
  const testStoreId = 'store-uuid-registered-999';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: testStoreId,
            name: 'Toko Kopi Mandiri',
            currency: const Value('IDR'),
            customerEnabled: const Value(true),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
      'Adding new customer in CustomerListScreen creates customer with active storeId and displays it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeStoreIdProvider.overrideWithValue(testStoreId),
        ],
        child: const MaterialApp(
          home: CustomerListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Initially empty
    expect(find.text('Belum ada data pelanggan'), findsOneWidget);

    // Tap FloatingActionButton "Pelanggan Baru"
    final addFab = find.text('Pelanggan Baru');
    await tester.tap(addFab);
    await tester.pumpAndSettle();

    // Dialog title
    expect(find.text('Tambah Pelanggan Baru'), findsOneWidget);

    // Enter customer details
    final nameField = find.widgetWithText(TextFormField, 'Nama Lengkap *');
    final phoneField =
        find.widgetWithText(TextFormField, 'Nomor WhatsApp / Telepon');
    final emailField = find.widgetWithText(TextFormField, 'Alamat Email');
    final notesField = find.widgetWithText(TextFormField, 'Catatan Khusus');

    await tester.enterText(nameField, 'Pak Bambang Sudirman');
    await tester.enterText(phoneField, '081298765432');
    await tester.enterText(emailField, 'bambang@example.com');
    await tester.enterText(notesField, 'Pelanggan VIP Kopi');
    await tester.pumpAndSettle();

    // Tap "Tambah"
    final saveButton = find.text('Tambah');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify dialog is closed and customer appears in the list!
    expect(find.text('Tambah Pelanggan Baru'), findsNothing);
    expect(find.text('Pak Bambang Sudirman'), findsOneWidget);
    expect(find.text('081298765432'), findsOneWidget);
    expect(find.text('bambang@example.com'), findsOneWidget);
    expect(find.text('Pelanggan VIP Kopi'), findsOneWidget);

    // Verify customer in DB has the active testStoreId
    final customersInDb = await db.customerDao.getAllCustomers(testStoreId);
    expect(customersInDb.length, equals(1));
    expect(customersInDb.first.storeId, equals(testStoreId));
    expect(customersInDb.first.name, equals('Pak Bambang Sudirman'));

    // Unmount and flush
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'Orphan customer saved with defaultStoreId is healed and displays in active store customer list',
      (WidgetTester tester) async {
    // Simulate customer saved under defaultStoreId due to previous bug
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: 'legacy-cust-001',
            storeId: AppConstants.defaultStoreId,
            name: 'Ibu Ratna Sari',
            phone: const Value('081345678901'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeStoreIdProvider.overrideWithValue(testStoreId),
        ],
        child: const MaterialApp(
          home: CustomerListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The legacy customer should be healed and displayed
    expect(find.text('Ibu Ratna Sari'), findsOneWidget);
    expect(find.text('081345678901'), findsOneWidget);

    // Verify in database it was healed to testStoreId
    final healed = await db.customerDao.getCustomerById('legacy-cust-001');
    expect(healed?.storeId, equals(testStoreId));

    // Unmount and flush
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
