import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/payment/widgets/payment_sheet.dart';
import 'package:mobile_pos/presentation/pos/controllers/cart_controller.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'store-default-01',
            name: 'Payment Test Store',
            currency: const Value('IDR'),
            cashRoundingEnabled: const Value(true),
            cashRoundingIncrement: const Value(1000),
            cashRoundingMode: const Value('ROUND_NEAREST'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('PaymentSheet displays payment methods and cash calculation properly',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );

    final now = DateTime.now();
    // Pre-populate cart with an item worth Rp 18.200 (should round to Rp 18.000)
    container.read(cartControllerProvider.notifier).addProduct(
          Product(
            id: 'prod-test',
            storeId: 'store-default-01',
            categoryId: 'cat-test',
            name: 'Kopi Susu Gula Aren',
            sellingPrice: 18200,
            cost: 8000,
            stock: 20,
            lowStockThreshold: 5,
            active: true,
            discontinued: false,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: PaymentSheet(),
          ),
        ),
      ),
    );

    // Pump to process cash rounding calculation and initial state
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Metode Pembayaran'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('QRIS'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Uang Pas'), findsOneWidget);

    // Switch to QRIS
    await tester.tap(find.text('QRIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SCAN QRIS'), findsOneWidget);

    // Switch to Transfer
    await tester.tap(find.text('Transfer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Rekening Bank Tujuan'), findsOneWidget);
    expect(find.text('Bank BCA'), findsOneWidget);

    // Unmount and flush pending timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
