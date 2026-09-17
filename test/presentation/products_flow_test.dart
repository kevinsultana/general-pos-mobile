import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/constants/app_constants.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/products/screens/product_form_screen.dart';
import 'package:mobile_pos/presentation/products/screens/product_list_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('ProductListScreen renders properly with empty catalog state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: ProductListScreen(),
        ),
      ),
    );

    // Pump to process database queries and UI stream
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Katalog Produk & Inventori'), findsOneWidget);
    expect(find.text('Belum Ada Produk'), findsOneWidget);
    expect(find.text('Tambah Produk'), findsOneWidget);

    // Unmount and flush any pending stream timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('ProductFormScreen displays all required product fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: ProductFormScreen(),
        ),
      ),
    );

    // Pump to process initial states
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tambah Produk Baru'), findsOneWidget);
    expect(find.text('Informasi Utama'), findsOneWidget);
    expect(find.text('Nama Produk *'), findsOneWidget);
    expect(find.text('Auto SKU'), findsOneWidget);
    expect(find.text('Harga Beli (HPP) *'), findsOneWidget);
    expect(find.text('Harga Jual *'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.text('Varian Produk (Opsional)'), findsOneWidget);
    expect(find.text('Buat Produk Baru'), findsOneWidget);

    // Unmount and flush any pending stream timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('ProductFormScreen makes master HPP and Harga Jual optional when variants are added',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: ProductFormScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Initially without variants, HPP and Harga Jual are mandatory
    expect(find.text('Harga Beli (HPP) *'), findsOneWidget);
    expect(find.text('Harga Jual *'), findsOneWidget);

    // Tap "+ Tambah Varian" button
    final addVariantBtn = find.text('Tambah Varian');
    expect(addVariantBtn, findsOneWidget);
    await tester.ensureVisible(addVariantBtn);
    await tester.pumpAndSettle();
    await tester.tap(addVariantBtn);
    await tester.pumpAndSettle();

    // Now HPP and Harga Jual on master become optional!
    final optionalHpp = find.text('Harga Beli (HPP) (Opsional)');
    await tester.ensureVisible(optionalHpp);
    expect(optionalHpp, findsOneWidget);

    final optionalPrice = find.text('Harga Jual (Opsional)');
    await tester.ensureVisible(optionalPrice);
    expect(optionalPrice, findsOneWidget);

    // Variant card has its own required price and HPP
    final variantName = find.text('Nama Varian #1 *');
    await tester.ensureVisible(variantName);
    expect(variantName, findsOneWidget);

    final variantHpp = find.text('HPP (Modal) *');
    await tester.ensureVisible(variantHpp);
    expect(variantHpp, findsOneWidget);

    // Unmount and flush
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'ProductFormScreen formats price and stock inputs with thousand separators',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: ProductFormScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Input Harga Beli (HPP)
    final hppField = find.widgetWithText(TextFormField, 'Harga Beli (HPP) *');
    await tester.ensureVisible(hppField);
    await tester.enterText(hppField, '1500000');
    await tester.pumpAndSettle();

    // Verify it formatted to 1.500.000
    expect(find.text('1.500.000'), findsOneWidget);

    // Input Harga Jual
    final priceField = find.widgetWithText(TextFormField, 'Harga Jual *');
    await tester.ensureVisible(priceField);
    await tester.enterText(priceField, '2500000');
    await tester.pumpAndSettle();

    // Verify it formatted to 2.500.000
    expect(find.text('2.500.000'), findsOneWidget);

    // Input Stok Awal
    final stockField = find.widgetWithText(TextFormField, 'Stok Awal *');
    await tester.ensureVisible(stockField);
    await tester.enterText(stockField, '1000');
    await tester.pumpAndSettle();

    // Verify it formatted to 1.000
    expect(find.text('1.000'), findsOneWidget);

    // Input Batas Stok Minimum
    final lowStockField =
        find.widgetWithText(TextFormField, 'Batas Stok Minimum');
    await tester.ensureVisible(lowStockField);
    await tester.enterText(lowStockField, '50');
    await tester.pumpAndSettle();

    expect(find.text('50'), findsOneWidget);

    // Unmount and flush
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'ProductListScreen renders product action buttons as icon-only with tooltips',
      (WidgetTester tester) async {
    // Insert store and product
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: AppConstants.defaultStoreId,
            name: 'Store Icon Test',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-icon-test',
            storeId: AppConstants.defaultStoreId,
            categoryId: 'cat-test',
            name: 'Kopi Susu Gula Aren',
            sku: const Value('KSGA-01'),
            sellingPrice: 18000,
            cost: 10000,
            stock: 25,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: ProductListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Kopi Susu Gula Aren'), findsOneWidget);

    // Verify action icon buttons exist by their tooltips
    final stockInButton = find.byTooltip('Stock In');
    final adjustButton = find.byTooltip('Sesuaikan Stok');
    final historyButton = find.byTooltip('Histori Stok');
    final barcodeButton = find.byTooltip('Cetak Label Barcode (CODE 128)');
    final editButton = find.byTooltip('Edit Produk');

    expect(stockInButton, findsOneWidget);
    expect(adjustButton, findsOneWidget);
    expect(historyButton, findsOneWidget);
    expect(barcodeButton, findsOneWidget);
    expect(editButton, findsOneWidget);

    // Verify icons inside the buttons
    expect(find.byIcon(Icons.add_shopping_cart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    // Verify that OutlinedButton with text labels no longer exist for these actions
    expect(find.widgetWithText(OutlinedButton, 'Stock In'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Sesuaikan'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Histori'), findsNothing);

    // Tap Stock In icon button to verify it opens the dialog
    await tester.tap(stockInButton);
    await tester.pumpAndSettle();

    expect(find.text('Stock In (Tambah Stok)'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Unmount and flush
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}


