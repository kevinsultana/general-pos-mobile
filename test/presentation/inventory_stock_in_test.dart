import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/inventory/widgets/stock_in_dialog.dart';

void main() {
  late AppDatabase db;
  late Product testProduct;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'test-store-inv',
            name: 'Inventory Test Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-stock-in-1',
            storeId: 'test-store-inv',
            categoryId: 'cat-test',
            name: 'Kopi Robusta Premium 1kg',
            sku: const Value('KRP-001'),
            sellingPrice: 85000,
            cost: 50000,
            stock: 20,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    testProduct = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-stock-in-1')))
        .getSingle();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
      'StockInDialog formats quantity and cost inputs with thousand separators without overflow',
      (WidgetTester tester) async {
    // Set mobile device size (narrow screen: 360 x 640)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StockInDialog(product: testProduct),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify dialog header
    expect(find.text('Stock In (Tambah Stok)'), findsOneWidget);
    expect(find.text('Kopi Robusta Premium 1kg'), findsOneWidget);

    // Initial cost should be formatted with thousand separator (50.000)
    expect(find.text('50.000'), findsOneWidget);

    // Input quantity: 15000 units
    final qtyField =
        find.widgetWithText(TextFormField, 'Jumlah Tambahan Unit *');
    await tester.ensureVisible(qtyField);
    await tester.enterText(qtyField, '15000');
    await tester.pumpAndSettle();

    // Verify it formatted to 15.000
    expect(find.text('15.000'), findsOneWidget);

    // Input cost: 55000
    final costField =
        find.widgetWithText(TextFormField, 'Harga Beli per Unit Baru (HPP) *');
    await tester.ensureVisible(costField);
    await tester.enterText(costField, '55000');
    await tester.pumpAndSettle();

    // Verify it formatted to 55.000
    expect(find.text('55.000'), findsOneWidget);

    // Verify HPP comparison preview exists without overflow
    expect(find.text('HPP Saat Ini'), findsOneWidget);
    expect(find.text('HPP Rata-Rata Baru'), findsOneWidget);

    // Simulate keyboard open by reducing available viewport height (keyboard takes ~300px)
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    // Ensure save button can be scrolled into view without crashing or overflowing
    final saveButton = find.text('Simpan Stok Masuk');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    expect(saveButton, findsOneWidget);

    // Reset view
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    // Unmount and flush
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
