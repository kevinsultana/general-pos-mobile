import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/main.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('App smoke test - Mode selection and local home flow', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const GeneralPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial screen is Mode Selection Screen
    expect(find.text('Mode Lokal (Offline POS)'), findsOneWidget);
    expect(find.text('Mode Cloud (Online Sync)'), findsOneWidget);

    // Tap Masuk Mode Lokal to trigger onboarding registration
    await tester.ensureVisible(find.text('Masuk Mode Lokal'));
    await tester.tap(find.text('Masuk Mode Lokal'));
    await tester.pumpAndSettle();

    // Verify redirected to Local Registration Screen
    expect(find.text('Registrasi Toko Lokal'), findsOneWidget);

    // Fill in required registration fields
    await tester.enterText(find.byKey(const Key('local_register_store_name')), 'Toko UMKM POS');
    await tester.enterText(find.byKey(const Key('local_register_store_address')), 'Jl. POS Sejahtera');
    await tester.enterText(find.byKey(const Key('local_register_store_phone')), '081234567890');
    await tester.enterText(find.byKey(const Key('local_register_admin_password')), 'admin123');
    await tester.enterText(find.byKey(const Key('local_register_admin_confirm_password')), 'admin123');

    // Submit registration
    final submitBtn = find.byKey(const Key('local_register_submit_button'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify that HomeScreen title and components are rendered
    expect(find.text('Buka Kasir'), findsOneWidget);
    // In local mode, cloud synchronization menu should NOT appear
    expect(find.text('Sinkronisasi Cloud'), findsNothing);
  });
}
