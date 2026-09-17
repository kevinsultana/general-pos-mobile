import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/store_repository_impl.dart';

void main() {
  late AppDatabase db;
  late StoreRepositoryImpl storeRepo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    storeRepo = StoreRepositoryImpl(db.storeDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Store & Admin Registration Flow Tests', () {
    test('isStoreRegistered returns false on a clean fresh database', () async {
      final isRegistered = await storeRepo.isStoreRegistered();
      expect(isRegistered, isFalse);
    });

    test('registerLocalStore successfully creates store and admin with UUID and hash', () async {
      final registeredStore = await storeRepo.registerLocalStore(
        name: 'Toko Sumber Rejeki',
        address: 'Jl. Merdeka No. 45, Jakarta Selatan',
        phone: '081298765432',
        ownerName: 'Pak Joko Widodo',
        adminUsername: 'admin_joko',
        adminPassword: 'password123',
        adminDisplayName: 'Joko (Super Admin)',
      );

      // Verify Store attributes
      expect(registeredStore, isNotNull);
      expect(registeredStore.name, equals('Toko Sumber Rejeki'));
      expect(registeredStore.address, equals('Jl. Merdeka No. 45, Jakarta Selatan'));
      expect(registeredStore.phone, equals('081298765432'));
      expect(registeredStore.ownerName, equals('Pak Joko Widodo'));
      expect(registeredStore.subscriptionPlan, equals('FREE'));
      expect(registeredStore.subscriptionStatus, equals('INACTIVE'));
      // Verify UUID v4 length (36 chars)
      expect(registeredStore.id.length, equals(36));
      expect(registeredStore.id, contains('-'));

      // Verify registration state is now true
      final isRegistered = await storeRepo.isStoreRegistered();
      expect(isRegistered, isTrue);

      // Verify Admin user was created and password hashed
      final adminUser = await storeRepo.getAdminUser(registeredStore.id);
      expect(adminUser, isNotNull);
      expect(adminUser!.username, equals('admin_joko'));
      expect(adminUser.displayName, equals('Joko (Super Admin)'));
      expect(adminUser.role, equals('ADMIN'));
      expect(adminUser.active, isTrue);
      expect(adminUser.storeId, equals(registeredStore.id));

      final expectedHash = sha256.convert(utf8.encode('password123')).toString();
      expect(adminUser.passwordHash, equals(expectedHash));
    });

    test('updateStoreProfile updates name, address, phone and owner atomically', () async {
      final store = await storeRepo.registerLocalStore(
        name: 'Toko Lama',
        address: 'Alamat Lama',
        phone: '0811111111',
        ownerName: 'Pemilik Lama',
        adminUsername: 'admin',
        adminPassword: 'password',
        adminDisplayName: 'Admin',
      );

      await storeRepo.updateStoreProfile(
        storeId: store.id,
        name: 'Toko Baru Makmur',
        address: 'Jl. Ahmad Yani No. 99',
        phone: '0899999999',
        ownerName: 'Pemilik Baru',
      );

      final updated = await storeRepo.getStore(store.id);
      expect(updated, isNotNull);
      expect(updated!.name, equals('Toko Baru Makmur'));
      expect(updated.address, equals('Jl. Ahmad Yani No. 99'));
      expect(updated.phone, equals('0899999999'));
      expect(updated.ownerName, equals('Pemilik Baru'));
    });

    test('isStoreRegistered returns false if only placeholder store exists without admin', () async {
      // Seed default store placeholder without admin
      await storeRepo.ensureDefaultStore();

      // Placeholder exists, but has no admin user registered
      final isRegistered = await storeRepo.isStoreRegistered();
      expect(isRegistered, isFalse);

      // Now register properly
      final store = await storeRepo.registerLocalStore(
        name: 'Warung Barokah',
        address: 'Jl. Sudirman No. 10',
        phone: '081111222333',
        adminUsername: 'admin',
        adminPassword: 'securepin1234',
        adminDisplayName: 'Admin Barokah',
      );

      expect(store.name, equals('Warung Barokah'));
      expect(await storeRepo.isStoreRegistered(), isTrue);

      // Cleaned up the old placeholder
      final oldPlaceholder = await storeRepo.getStore('store-default-01');
      expect(oldPlaceholder, isNull);
    });
  });
}
