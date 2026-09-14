import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/pos/screens/pos_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    // Seed store and product
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'store-default-01',
            name: 'POS Test Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'test-item-1',
            storeId: 'store-default-01',
            categoryId: 'cat-drink',
            name: 'Es Teh Manis',
            sku: const Value('ETM-001'),
            sellingPrice: 5000,
            cost: 2000,
            stock: 50,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('PosScreen renders catalog, adds product to cart, and shows bottom bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: PosScreen(),
        ),
      ),
    );

    // Pump to process database queries and UI stream
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Kasir POS'), findsOneWidget);
    expect(find.text('Es Teh Manis'), findsOneWidget);
    expect(find.text('Rp 5.000'), findsOneWidget);

    // Tap product to add to cart
    await tester.tap(find.text('Es Teh Manis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Floating cart bar should now be visible with 1 item and Rp 5.000 total
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Keranjang'), findsOneWidget);

    // Unmount and flush pending stream timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
