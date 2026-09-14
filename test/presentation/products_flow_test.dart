import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Varian Produk (Opsional)'), findsOneWidget);
    expect(find.text('Buat Produk Baru'), findsOneWidget);

    // Unmount and flush any pending stream timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
