import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/mode_select/screens/local_register_screen.dart';
import 'package:mobile_pos/presentation/mode_select/screens/mode_selection_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget home) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: home,
      ),
    );
  }

  group('LocalRegisterScreen Widget Tests', () {
    testWidgets('renders all registration form inputs and initial states', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const LocalRegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Registrasi Toko Lokal'), findsOneWidget);
      expect(find.text('Informasi Toko'), findsOneWidget);
      expect(find.text('Akun Administrator Lokal'), findsOneWidget);
      expect(find.byKey(const Key('local_register_store_name')), findsOneWidget);
      expect(find.byKey(const Key('local_register_store_address')), findsOneWidget);
      expect(find.byKey(const Key('local_register_store_phone')), findsOneWidget);
      expect(find.byKey(const Key('local_register_admin_username')), findsOneWidget);
      expect(find.byKey(const Key('local_register_admin_password')), findsOneWidget);
      expect(find.byKey(const Key('local_register_admin_confirm_password')), findsOneWidget);
      expect(find.byKey(const Key('local_register_submit_button')), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const LocalRegisterScreen()));
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('local_register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Nama toko wajib diisi'), findsOneWidget);
      expect(find.text('Alamat toko wajib diisi'), findsOneWidget);
      expect(find.text('Nomor telepon wajib diisi'), findsOneWidget);
      expect(find.text('Password sementara wajib diisi'), findsOneWidget);
    });

    testWidgets('successfully registers local store and creates database records', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/local-register',
        routes: [
          GoRoute(
            path: '/local-register',
            builder: (context, state) => const LocalRegisterScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home Screen Pos')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter store details
      await tester.enterText(find.byKey(const Key('local_register_store_name')), 'Toko Sinar Jaya');
      await tester.enterText(find.byKey(const Key('local_register_store_address')), 'Jl. Pahlawan No. 8');
      await tester.enterText(find.byKey(const Key('local_register_store_phone')), '08123456789');
      await tester.enterText(find.byKey(const Key('local_register_owner_name')), 'Budi Gunawan');

      // Enter admin details
      await tester.enterText(find.byKey(const Key('local_register_admin_username')), 'admin_budi');
      await tester.enterText(find.byKey(const Key('local_register_admin_password')), 'secret123');
      await tester.enterText(find.byKey(const Key('local_register_admin_confirm_password')), 'secret123');

      final submitBtn = find.byKey(const Key('local_register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify routed to home
      expect(find.text('Home Screen Pos'), findsOneWidget);

      // Verify store exists in DB
      final store = await db.storeDao.getFirstStore();
      expect(store, isNotNull);
      expect(store!.name, equals('Toko Sinar Jaya'));
      expect(store.address, equals('Jl. Pahlawan No. 8'));
      expect(store.phone, equals('08123456789'));

      // Verify admin user exists in DB
      final admin = await db.userDao.getAdminUser(store.id);
      expect(admin, isNotNull);
      expect(admin!.username, equals('admin_budi'));
      expect(admin.role, equals('ADMIN'));
    });
  });

  group('ModeSelectionScreen to Local Register Flow Tests', () {
    testWidgets('tapping Masuk Mode Lokal navigates to /local-register when unregistered',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/mode-select',
        routes: [
          GoRoute(
            path: '/mode-select',
            builder: (context, state) => const ModeSelectionScreen(),
          ),
          GoRoute(
            path: '/local-register',
            builder: (context, state) => const Scaffold(body: Text('Screen Register Lokal')),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home Screen Pos')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap "Masuk Mode Lokal"
      final localModeBtn = find.text('Masuk Mode Lokal');
      expect(localModeBtn, findsOneWidget);
      await tester.ensureVisible(localModeBtn);
      await tester.tap(localModeBtn);
      await tester.pumpAndSettle();

      // Should have navigated to Screen Register Lokal
      expect(find.text('Screen Register Lokal'), findsOneWidget);
    });

    testWidgets('tapping Masuk Mode Lokal navigates directly to / when already registered',
        (WidgetTester tester) async {
      // Pre-register store and admin
      final storeRepo = db.storeDao;
      await storeRepo.registerLocalStore(
        storeId: 'registered-store-01',
        name: 'Toko Terdaftar',
        address: 'Alamat Toko',
        phone: '08123456789',
        adminUserId: 'admin-user-01',
        adminUsername: 'admin',
        adminPasswordHash: 'hash',
        adminDisplayName: 'Admin',
      );

      final router = GoRouter(
        initialLocation: '/mode-select',
        routes: [
          GoRoute(
            path: '/mode-select',
            builder: (context, state) => const ModeSelectionScreen(),
          ),
          GoRoute(
            path: '/local-register',
            builder: (context, state) => const Scaffold(body: Text('Screen Register Lokal')),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home Screen Pos')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap "Masuk Mode Lokal"
      final localModeBtn = find.text('Masuk Mode Lokal');
      expect(localModeBtn, findsOneWidget);
      await tester.ensureVisible(localModeBtn);
      await tester.tap(localModeBtn);
      await tester.pumpAndSettle();

      // Should have navigated directly to Home Screen Pos
      expect(find.text('Home Screen Pos'), findsOneWidget);
      expect(find.text('Screen Register Lokal'), findsNothing);
    });
  });
}
