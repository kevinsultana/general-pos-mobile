import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/services/backup_service.dart';
import 'package:mobile_pos/data/repositories/backup_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BackupService backupService;
  late BackupRepositoryImpl backupRepo;
  late Directory tempBackupDir;
  const storeId = 'store-test-backup';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    tempBackupDir = Directory.systemTemp.createTempSync('pos_test_backups_');
    backupService = BackupService(db, customBackupDir: tempBackupDir);
    backupRepo = BackupRepositoryImpl(backupService);

    final now = DateTime.now();

    // Populate baseline data
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Kopi Mantap Backup Store',
            currency: const Value('IDR'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-backup-01',
            storeId: storeId,
            categoryId: 'cat-default',
            name: 'Kopi Espresso',
            cost: 5000,
            sellingPrice: 15000,
            stock: 50,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: 'cust-backup-01',
            storeId: storeId,
            name: 'Ahmad Fauzi',
            phone: const Value('08123456789'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'trx-backup-01',
            storeId: storeId,
            transactionNumber: 'TRX-B01',
            status: 'COMPLETED',
            subtotal: 15000,
            total: 15000,
            customerId: const Value('cust-backup-01'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (tempBackupDir.existsSync()) {
      tempBackupDir.deleteSync(recursive: true);
    }
  });

  test('Backup export, validation, and atomic restore lifecycle works', () async {
    // 1. Create encrypted backup
    final backup = await backupRepo.createBackup(
      storeId: storeId,
      password: 'SecurePassword123!',
    );

    expect(backup.fileName.endsWith('.posbak'), isTrue);
    expect(backup.fileSizeBytes, greaterThan(0));
    expect(backup.transactionCount, equals(1));
    expect(backup.productCount, equals(1));
    expect(backup.checksum, isNotNull);

    // 2. List backups
    final list = await backupRepo.listBackups();
    expect(list.length, equals(1));
    expect(list.first.fileName, equals(backup.fileName));

    // 3. Validation
    // Valid password -> true
    final isValid = await backupRepo.validateBackup(
      backup.filePath,
      password: 'SecurePassword123!',
    );
    expect(isValid, isTrue);

    // Wrong password -> false
    final isWrongPassValid = await backupRepo.validateBackup(
      backup.filePath,
      password: 'WrongPassword!',
    );
    expect(isWrongPassValid, isFalse);

    // 4. Modify / wipe local database
    await db.delete(db.transactions).go();
    await db.delete(db.customers).go();
    await db.delete(db.products).go();

    final remainingProducts = await db.select(db.products).get();
    expect(remainingProducts, isEmpty);
    final remainingTrx = await db.select(db.transactions).get();
    expect(remainingTrx, isEmpty);

    // 5. Restore database with correct password
    await backupRepo.restoreBackup(
      backup.filePath,
      password: 'SecurePassword123!',
    );

    // 6. Verify restored data
    final restoredProducts = await db.select(db.products).get();
    expect(restoredProducts.length, equals(1));
    expect(restoredProducts.first.name, equals('Kopi Espresso'));
    expect(restoredProducts.first.stock, equals(50));

    final restoredCustomers = await db.select(db.customers).get();
    expect(restoredCustomers.length, equals(1));
    expect(restoredCustomers.first.name, equals('Ahmad Fauzi'));

    final restoredTrx = await db.select(db.transactions).get();
    expect(restoredTrx.length, equals(1));
    expect(restoredTrx.first.transactionNumber, equals('TRX-B01'));

    // 7. Delete backup
    final deleted = await backupRepo.deleteBackup(backup.filePath);
    expect(deleted, isTrue);
    final listAfterDelete = await backupRepo.listBackups();
    expect(listAfterDelete, isEmpty);
  });

  test('Backup can be saved to custom directory path and inspected', () async {
    final customFolder = Directory.systemTemp.createTempSync('custom_target_dir_');
    try {
      final backup = await backupRepo.createBackup(
        storeId: storeId,
        targetDirectoryPath: customFolder.path,
      );

      expect(backup.filePath.startsWith(customFolder.path), isTrue);
      expect(File(backup.filePath).existsSync(), isTrue);

      final inspected = await backupRepo.inspectBackupFile(backup.filePath);
      expect(inspected, isNotNull);
      expect(inspected!.fileName, equals(backup.fileName));
      expect(inspected.transactionCount, equals(1));
    } finally {
      if (customFolder.existsSync()) {
        customFolder.deleteSync(recursive: true);
      }
    }
  });

  test('resetDatabaseToInitial wipes all transactional records and re-seeds clean default store', () async {
    // Verify baseline has records
    expect((await db.select(db.products).get()).length, equals(1));
    expect((await db.select(db.transactions).get()).length, equals(1));
    expect((await db.select(db.customers).get()).length, equals(1));

    // Execute Factory Reset
    await backupRepo.resetDatabaseToInitial(storeId: 'store-default-01');

    // All business records wiped
    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.customers).get(), isEmpty);
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.stockMovements).get(), isEmpty);

    // Default clean store re-seeded
    final stores = await db.select(db.stores).get();
    expect(stores.length, equals(1));
    expect(stores.first.id, equals('store-default-01'));
    expect(stores.first.name, equals('Toko UMKM POS'));
    expect(stores.first.customerEnabled, isFalse);
  });
}
