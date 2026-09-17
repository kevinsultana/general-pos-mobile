import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/cloud_providers.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/presentation/settings/screens/store_settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    // Seed local store
    await db.storeDao.registerLocalStore(
      storeId: 'test-store-id-01',
      name: 'Toko Kelontong Berkah',
      address: 'Jl. Melati No. 12',
      phone: '081234567890',
      ownerName: 'Haji Mansur',
      adminUserId: 'test-user-id-01',
      adminUsername: 'admin',
      adminPasswordHash: 'hash',
      adminDisplayName: 'Admin',
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        home: StoreSettingsScreen(),
      ),
    );
  }

  group('StoreSettingsScreen Profile & PRO Package Tests', () {
    testWidgets('renders store details and shows Paket PRO Tidak Aktif in local mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify store details are shown
      expect(find.text('Toko Kelontong Berkah'), findsOneWidget);
      expect(find.text('Jl. Melati No. 12'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('Pemilik: Haji Mansur'), findsOneWidget);

      // Verify PRO Inactive badge and explanation banner
      expect(find.text('Paket PRO Tidak Aktif'), findsOneWidget);
      expect(find.text('Paket PRO Tidak Aktif (Mode Lokal)'), findsOneWidget);
      expect(find.text('Daftar / Sinkronisasi Cloud Sekarang'), findsOneWidget);
    });

    testWidgets('tapping store card opens edit dialog and updates store details',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap store profile card
      final cardTap = find.byKey(const Key('store_profile_card_tap'));
      expect(cardTap, findsOneWidget);
      await tester.tap(cardTap);
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.text('Edit Informasi Toko'), findsOneWidget);

      // Verify pre-filled inputs
      final nameField = find.byKey(const Key('edit_store_name_field'));
      final addressField = find.byKey(const Key('edit_store_address_field'));
      final phoneField = find.byKey(const Key('edit_store_phone_field'));
      final ownerField = find.byKey(const Key('edit_store_owner_field'));

      expect(nameField, findsOneWidget);
      expect(addressField, findsOneWidget);
      expect(phoneField, findsOneWidget);
      expect(ownerField, findsOneWidget);

      // Edit fields
      await tester.enterText(nameField, 'Toko Kelontong Berkah Sejahtera');
      await tester.enterText(addressField, 'Jl. Mawar Indah No. 99');
      await tester.enterText(phoneField, '089876543210');
      await tester.enterText(ownerField, 'Haji Mansur S.E.');

      // Submit
      final saveBtn = find.byKey(const Key('save_store_details_button'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify dialog closed and snackbar appears
      expect(find.text('Edit Informasi Toko'), findsNothing);
      expect(find.text('Detail toko berhasil diperbarui'), findsOneWidget);

      // Verify card updated reactively
      expect(find.text('Toko Kelontong Berkah Sejahtera'), findsOneWidget);
      expect(find.text('Jl. Mawar Indah No. 99'), findsOneWidget);
      expect(find.text('089876543210'), findsOneWidget);
      expect(find.text('Pemilik: Haji Mansur S.E.'), findsOneWidget);

      // Verify database updated
      final storeInDb = await db.storeDao.getStoreById('test-store-id-01');
      expect(storeInDb, isNotNull);
      expect(storeInDb!.name, equals('Toko Kelontong Berkah Sejahtera'));
      expect(storeInDb.address, equals('Jl. Mawar Indah No. 99'));
      expect(storeInDb.phone, equals('089876543210'));
      expect(storeInDb.ownerName, equals('Haji Mansur S.E.'));
    });
  });
}
