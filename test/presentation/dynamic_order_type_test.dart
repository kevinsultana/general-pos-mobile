import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/domain/models/store_ext.dart';
import 'package:mobile_pos/presentation/pos/controllers/cart_controller.dart';
import 'package:mobile_pos/presentation/pos/widgets/cart_bottom_sheet.dart';
import 'package:mobile_pos/presentation/settings/screens/store_settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    await db.storeDao.registerLocalStore(
      storeId: 'store-order-type-test',
      name: 'Toko Kopi Dinamis',
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

  group('Dynamic Order Type Tests', () {
    testWidgets(
        'StoreSettingsScreen opens OrderTypeSettingsScreen, renders order type toggle and allows adding a new order type',
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

      // 1. Verify tile exists in StoreSettingsScreen
      final tileFinder = find.byKey(const Key('order_type_settings_tile'));
      expect(tileFinder, findsOneWidget);
      expect(find.text('Pilihan Tipe Pesanan'), findsOneWidget);

      // Tap to open OrderTypeSettingsScreen
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // 2. In OrderTypeSettingsScreen: verify toggle exists
      expect(find.byKey(const Key('order_type_switch')), findsOneWidget);

      // 3. Verify default order types are displayed
      expect(find.text('Dine In'), findsWidgets);
      expect(find.text('Takeaway'), findsWidgets);
      expect(find.text('Delivery'), findsWidgets);
      expect(find.text('Online'), findsWidgets);

      // 4. Tap 'Tambah Opsi'
      final addBtn = find.byKey(const Key('add_order_type_button'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // 5. Verify Add Dialog opened
      expect(find.text('Tambah Tipe Pesanan'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Ojol Super');
      await tester.pump();

      // Tap 'Tambah' button in dialog
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      // 6. Verify 'Ojol Super' is now displayed and in DB
      expect(find.text('Ojol Super'), findsWidgets);
      final store = await db.storeDao.getFirstStore();
      expect(store?.orderTypesList.contains('Ojol Super'), isTrue);

      // Unmount cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        'CartBottomSheet renders dynamic options as text chips without icons, and hides when disabled',
        (WidgetTester tester) async {
      // Set custom order types in store
      await db.storeDao.updateOrderTypes(
        storeId: 'store-order-type-test',
        orderTypes: ['Makan Sini', 'Bungkus', 'Gojek'],
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentStoreStreamProvider
              .overrideWith((ref) => db.storeDao.watchFirstStore()),
        ],
      );
      addTearDown(container.dispose);

      // Add dummy item to cart
      final cartNotifier = container.read(cartControllerProvider.notifier);
      final now = DateTime.now();
      cartNotifier.addProduct(
        Product(
          id: 'prod-01',
          storeId: 'store-order-type-test',
          categoryId: 'cat-test',
          name: 'Kopi Susu Gula Aren',
          sellingPrice: 18000,
          cost: 8000,
          stock: 10,
          lowStockThreshold: 2,
          active: true,
          discontinued: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Pump CartBottomSheet inside UncontrolledProviderScope
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CartBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify custom options are rendered as text chips
      expect(find.text('Makan Sini'), findsOneWidget);
      expect(find.text('Bungkus'), findsOneWidget);
      expect(find.text('Gojek'), findsOneWidget);

      // Verify no Material Icons (dine_in, takeaway, delivery, etc) are used
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
      expect(find.byIcon(Icons.takeout_dining_rounded), findsNothing);
      expect(find.byIcon(Icons.delivery_dining_rounded), findsNothing);

      // Tap 'Bungkus'
      await tester.tap(find.text('Bungkus'));
      await tester.pumpAndSettle();

      // Verify cart state updated
      expect(container.read(cartControllerProvider).orderType, 'Bungkus');

      // Now disable orderTypeEnabled in store
      await db.storeDao.setOrderTypeEnabled('store-order-type-test', false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the order type selector is completely hidden
      expect(find.text('Makan Sini'), findsNothing);
      expect(find.text('Bungkus'), findsNothing);
      expect(find.text('Gojek'), findsNothing);

      // Unmount cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('StoreSettingsScreen does not overflow on narrow width (262px)',
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

      final tileFinder = find.byKey(const Key('order_type_settings_tile'));
      expect(tileFinder, findsOneWidget);
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.text('Daftar Pilihan Aktif'), findsOneWidget);
      expect(find.text('Reset Default'), findsOneWidget);
      expect(find.byKey(const Key('add_order_type_button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
