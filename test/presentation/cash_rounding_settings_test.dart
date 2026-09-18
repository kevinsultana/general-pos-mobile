import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/settings/screens/store_settings_screen.dart';
import 'package:mobile_pos/presentation/settings/screens/cash_rounding_settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    await db.storeDao.registerLocalStore(
      storeId: 'store-rounding-test',
      name: 'Warung Rounding',
      address: 'Jl. Kopi No. 5',
      phone: '0812345678',
      adminUserId: 'user-01',
      adminUsername: 'admin',
      adminPasswordHash: 'hash',
      adminDisplayName: 'Admin',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Cash Rounding Settings Tests', () {
    testWidgets(
        'StoreSettingsScreen opens CashRoundingSettingsScreen and toggles switch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentStoreStreamProvider
                .overrideWith((ref) => db.storeDao.watchFirstStore()),
          ],
          child: const MaterialApp(
            home: StoreSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Cash Rounding tile is in FITUR POS & TRANSAKSI
      final tileFinder = find.byKey(const Key('cash_rounding_settings_tile'));
      expect(tileFinder, findsOneWidget);
      expect(find.text('Pembulatan Tunai'), findsOneWidget);

      // 2. Tap to open CashRoundingSettingsScreen
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // 3. Verify in CashRoundingSettingsScreen
      expect(find.byKey(const Key('cash_rounding_switch')), findsOneWidget);
      expect(find.text('Status Pembulatan Tunai'), findsOneWidget);
      expect(find.text('Kelipatan Pembulatan (Increment)'), findsOneWidget);
      expect(find.text('Metode Pembulatan'), findsOneWidget);
      expect(find.text('Simulasi Perhitungan di Kasir'), findsOneWidget);

      // 4. Toggle Cash Rounding switch to false
      await tester.tap(find.byKey(const Key('cash_rounding_switch')));
      await tester.pumpAndSettle();

      var store = await db.storeDao.getFirstStore();
      expect(store?.cashRoundingEnabled, isFalse);

      // 5. Toggle Cash Rounding switch back to true
      await tester.tap(find.byKey(const Key('cash_rounding_switch')));
      await tester.pumpAndSettle();

      store = await db.storeDao.getFirstStore();
      expect(store?.cashRoundingEnabled, isTrue);

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        'Selecting increment and mode updates database and simulation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentStoreStreamProvider
                .overrideWith((ref) => db.storeDao.watchFirstStore()),
          ],
          child: const MaterialApp(
            home: CashRoundingSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Select increment 500
      await tester.tap(find.byKey(const Key('increment_500')));
      await tester.pumpAndSettle();

      var store = await db.storeDao.getFirstStore();
      expect(store?.cashRoundingIncrement, equals(500));

      // Select mode ROUND_UP
      await tester.tap(find.byKey(const Key('mode_ROUND_UP')));
      await tester.pumpAndSettle();

      store = await db.storeDao.getFirstStore();
      expect(store?.cashRoundingMode, equals('ROUND_UP'));

      // Select mode ROUND_DOWN
      await tester.tap(find.byKey(const Key('mode_ROUND_DOWN')));
      await tester.pumpAndSettle();

      store = await db.storeDao.getFirstStore();
      expect(store?.cashRoundingMode, equals('ROUND_DOWN'));

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        'StoreSettingsScreen and CashRoundingSettingsScreen do not overflow on narrow width (262px)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(262, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentStoreStreamProvider
                .overrideWith((ref) => db.storeDao.watchFirstStore()),
          ],
          child: const MaterialApp(
            home: StoreSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final tileFinder = find.byKey(const Key('cash_rounding_settings_tile'));
      expect(tileFinder, findsOneWidget);
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cash_rounding_switch')), findsOneWidget);
      expect(find.text('Status Pembulatan Tunai'), findsOneWidget);
      final simFinder = find.text('Simulasi Perhitungan di Kasir');
      await tester.scrollUntilVisible(simFinder, 500);
      await tester.pumpAndSettle();
      expect(simFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
