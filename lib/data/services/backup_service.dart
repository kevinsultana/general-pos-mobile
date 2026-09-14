import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/app_database.dart';
import '../../domain/models/backup_info.dart';

class BackupService {
  final AppDatabase _db;
  final Directory? customBackupDir;

  BackupService(this._db, {this.customBackupDir});

  Future<Directory> getBackupDirectory() async {
    if (customBackupDir != null) {
      if (!await customBackupDir!.exists()) {
        await customBackupDir!.create(recursive: true);
      }
      return customBackupDir!;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docsDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<List<String>> getSuggestedBackupDirectories() async {
    final list = <String>[];
    try {
      final defaultDir = await getBackupDirectory();
      list.add(defaultDir.path);
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final extBackup = p.join(extDir.path, 'backups');
        if (!list.contains(extBackup)) {
          list.add(extBackup);
        }
      }
    } catch (_) {}

    if (Platform.isAndroid) {
      const androidDownload = '/storage/emulated/0/Download';
      if (await Directory(androidDownload).exists()) {
        list.add(androidDownload);
      }
      const androidDocuments = '/storage/emulated/0/Documents';
      if (await Directory(androidDocuments).exists()) {
        list.add(androidDocuments);
      }
    }

    return list;
  }

  enc.Key _deriveKey(String? password) {
    final baseStr = password != null && password.trim().isNotEmpty
        ? 'UMKM_POS_SALT_${password.trim()}'
        : 'UMKM_POS_DEFAULT_SECURE_SALT_2026_MASTER_KEY';
    final hashBytes = sha256.convert(utf8.encode(baseStr)).bytes;
    return enc.Key(Uint8List.fromList(hashBytes));
  }

  Future<BackupFileInfo> createBackup({
    required String storeId,
    String? password,
    String? targetDirectoryPath,
  }) async {
    // 1. Gather all dataset from local SQLite
    final stores = await _db.select(_db.stores).get();
    final categories = await _db.select(_db.categories).get();
    final products = await _db.select(_db.products).get();
    final variants = await _db.select(_db.productVariants).get();
    final movements = await _db.select(_db.stockMovements).get();
    final customers = await _db.select(_db.customers).get();
    final promotions = await _db.select(_db.promotions).get();
    final transactions = await _db.select(_db.transactions).get();
    final transactionItems = await _db.select(_db.transactionItems).get();
    final payments = await _db.select(_db.payments).get();
    final paymentMethods = await _db.select(_db.paymentMethods).get();
    final refunds = await _db.select(_db.refunds).get();
    final refundItems = await _db.select(_db.refundItems).get();

    final now = DateTime.now();
    final currentStore =
        stores.where((s) => s.id == storeId).firstOrNull ?? stores.firstOrNull;

    final payloadMap = <String, dynamic>{
      'version': 1,
      'createdAt': now.toIso8601String(),
      'storeId': storeId,
      'storeName': currentStore?.name ?? 'UMKM POS',
      'tables': {
        'stores': stores.map((s) => s.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'productVariants': variants.map((v) => v.toJson()).toList(),
        'stockMovements': movements.map((m) => m.toJson()).toList(),
        'customers': customers.map((c) => c.toJson()).toList(),
        'promotions': promotions.map((p) => p.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'transactionItems': transactionItems.map((i) => i.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'paymentMethods': paymentMethods.map((m) => m.toJson()).toList(),
        'refunds': refunds.map((r) => r.toJson()).toList(),
        'refundItems': refundItems.map((ri) => ri.toJson()).toList(),
      },
    };

    final rawJsonString = jsonEncode(payloadMap);
    final rawChecksum = sha256.convert(utf8.encode(rawJsonString)).toString();

    // 2. Encrypt payload with AES-256-CBC
    final key = _deriveKey(password);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(rawJsonString, iv: iv);

    // 3. Build Envelope
    final envelope = <String, dynamic>{
      'magic': 'POSBAK1',
      'version': 1,
      'createdAt': now.toIso8601String(),
      'storeId': storeId,
      'storeName': currentStore?.name ?? 'UMKM POS',
      'checksum': rawChecksum,
      'iv': iv.base64,
      'encryptedData': encrypted.base64,
      'summary': {
        'transactionCount': transactions.length,
        'productCount': products.length,
        'customerCount': customers.length,
      },
    };

    // 4. Save to target directory
    final Directory backupDir;
    if (targetDirectoryPath != null && targetDirectoryPath.trim().isNotEmpty) {
      backupDir = Directory(targetDirectoryPath.trim());
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
    } else {
      backupDir = await getBackupDirectory();
    }

    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'pos_backup_$timestamp.posbak';
    final file = File(p.join(backupDir.path, fileName));

    await file.writeAsString(jsonEncode(envelope));
    final size = await file.length();

    return BackupFileInfo(
      filePath: file.path,
      fileName: fileName,
      createdAt: now,
      fileSizeBytes: size,
      storeId: storeId,
      storeName: currentStore?.name ?? 'UMKM POS',
      transactionCount: transactions.length,
      productCount: products.length,
      checksum: rawChecksum,
    );
  }

  Future<List<BackupFileInfo>> listBackups({String? directoryPath}) async {
    final Directory backupDir;
    if (directoryPath != null && directoryPath.trim().isNotEmpty) {
      backupDir = Directory(directoryPath.trim());
    } else {
      backupDir = await getBackupDirectory();
    }

    if (!await backupDir.exists()) return [];

    final entities = backupDir.listSync();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.posbak'))
        .toList();

    final result = <BackupFileInfo>[];

    for (final file in files) {
      final info = await inspectBackupFile(file.path);
      if (info != null) {
        result.add(info);
      }
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<BackupFileInfo?> inspectBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final envelope = jsonDecode(content) as Map<String, dynamic>;
      if (envelope['magic'] != 'POSBAK1') return null;

      final summary = envelope['summary'] as Map<String, dynamic>?;
      final size = await file.length();
      final createdAt =
          DateTime.tryParse(envelope['createdAt'] as String? ?? '') ??
              file.lastModifiedSync();

      return BackupFileInfo(
        filePath: file.path,
        fileName: p.basename(file.path),
        createdAt: createdAt,
        fileSizeBytes: size,
        storeId: envelope['storeId'] as String?,
        storeName: envelope['storeName'] as String?,
        transactionCount: summary?['transactionCount'] as int?,
        productCount: summary?['productCount'] as int?,
        checksum: envelope['checksum'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> validateBackup(String filePath, {String? password}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final content = await file.readAsString();
      final envelope = jsonDecode(content) as Map<String, dynamic>;
      if (envelope['magic'] != 'POSBAK1') return false;

      final key = _deriveKey(password);
      final iv = enc.IV.fromBase64(envelope['iv'] as String);
      final encryptedData = envelope['encryptedData'] as String;
      final expectedChecksum = envelope['checksum'] as String;

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decryptedString = encrypter.decrypt64(encryptedData, iv: iv);

      final computedChecksum =
          sha256.convert(utf8.encode(decryptedString)).toString();
      if (computedChecksum != expectedChecksum) return false;

      final payload = jsonDecode(decryptedString) as Map<String, dynamic>;
      if (!payload.containsKey('tables')) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> restoreBackup(String filePath, {String? password}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException('File cadangan tidak ditemukan');
    }

    final content = await file.readAsString();
    final envelope = jsonDecode(content) as Map<String, dynamic>;
    if (envelope['magic'] != 'POSBAK1') {
      throw const FormatException(
          'Format file cadangan tidak valid (Magic header mismatch)');
    }

    final key = _deriveKey(password);
    final iv = enc.IV.fromBase64(envelope['iv'] as String);
    final encryptedData = envelope['encryptedData'] as String;
    final expectedChecksum = envelope['checksum'] as String;

    String decryptedString;
    try {
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      decryptedString = encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      throw const FormatException('Kata sandi cadangan salah atau enkripsi rusak');
    }

    final computedChecksum =
        sha256.convert(utf8.encode(decryptedString)).toString();
    if (computedChecksum != expectedChecksum) {
      throw const FormatException(
          'Integritas data cadangan rusak (Checksum mismatch)');
    }

    final payload = jsonDecode(decryptedString) as Map<String, dynamic>;
    final tables = payload['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw const FormatException(
          'Data tabel tidak ditemukan dalam file cadangan');
    }

    // Atomic Restore inside Drift transaction to prevent partial corruption
    await _db.transaction(() async {
      // 1. Clear tables in reverse dependency order
      await _db.delete(_db.refundItems).go();
      await _db.delete(_db.refunds).go();
      await _db.delete(_db.payments).go();
      await _db.delete(_db.paymentMethods).go();
      await _db.delete(_db.transactionItems).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.promotions).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.stockMovements).go();
      await _db.delete(_db.productVariants).go();
      await _db.delete(_db.products).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.printers).go();
      await _db.delete(_db.syncEvents).go();
      await _db.delete(_db.syncCursors).go();
      await _db.delete(_db.stores).go();

      // 2. Insert stores
      final storeRows = (tables['stores'] as List?) ?? [];
      for (final s in storeRows) {
        final item = Store.fromJson(s as Map<String, dynamic>);
        await _db.into(_db.stores).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 3. Insert categories
      final catRows = (tables['categories'] as List?) ?? [];
      for (final c in catRows) {
        final item = Category.fromJson(c as Map<String, dynamic>);
        await _db.into(_db.categories).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 4. Insert products
      final prodRows = (tables['products'] as List?) ?? [];
      for (final p in prodRows) {
        final item = Product.fromJson(p as Map<String, dynamic>);
        await _db.into(_db.products).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 5. Insert product variants
      final variantRows = (tables['productVariants'] as List?) ?? [];
      for (final v in variantRows) {
        final item = ProductVariant.fromJson(v as Map<String, dynamic>);
        await _db.into(_db.productVariants).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 6. Insert stock movements
      final movRows = (tables['stockMovements'] as List?) ?? [];
      for (final m in movRows) {
        final item = StockMovement.fromJson(m as Map<String, dynamic>);
        await _db.into(_db.stockMovements).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 7. Insert customers
      final custRows = (tables['customers'] as List?) ?? [];
      for (final c in custRows) {
        final item = Customer.fromJson(c as Map<String, dynamic>);
        await _db.into(_db.customers).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 8. Insert promotions
      final promoRows = (tables['promotions'] as List?) ?? [];
      for (final p in promoRows) {
        final item = Promotion.fromJson(p as Map<String, dynamic>);
        await _db.into(_db.promotions).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 9. Insert transactions
      final trxRows = (tables['transactions'] as List?) ?? [];
      for (final t in trxRows) {
        final item = Transaction.fromJson(t as Map<String, dynamic>);
        await _db.into(_db.transactions).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 10. Insert transaction items
      final itmRows = (tables['transactionItems'] as List?) ?? [];
      for (final i in itmRows) {
        final item = TransactionItem.fromJson(i as Map<String, dynamic>);
        await _db.into(_db.transactionItems).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 11. Insert payment methods
      final methodRows = (tables['paymentMethods'] as List?) ?? [];
      for (final m in methodRows) {
        final item = PaymentMethod.fromJson(m as Map<String, dynamic>);
        await _db.into(_db.paymentMethods).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 12. Insert payments
      final payRows = (tables['payments'] as List?) ?? [];
      for (final p in payRows) {
        final item = Payment.fromJson(p as Map<String, dynamic>);
        await _db.into(_db.payments).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 13. Insert refunds
      final refRows = (tables['refunds'] as List?) ?? [];
      for (final r in refRows) {
        final item = Refund.fromJson(r as Map<String, dynamic>);
        await _db.into(_db.refunds).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }

      // 14. Insert refund items
      final refItmRows = (tables['refundItems'] as List?) ?? [];
      for (final ri in refItmRows) {
        final item = RefundItem.fromJson(ri as Map<String, dynamic>);
        await _db.into(_db.refundItems).insert(item.toCompanion(false),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> resetDatabaseToInitial({String storeId = 'store-default-01'}) async {
    await _db.transaction(() async {
      // 1. Wipe child and transaction tables
      await _db.delete(_db.refundItems).go();
      await _db.delete(_db.refunds).go();
      await _db.delete(_db.payments).go();
      await _db.delete(_db.paymentMethods).go();
      await _db.delete(_db.transactionItems).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.promotions).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.stockMovements).go();
      await _db.delete(_db.productVariants).go();
      await _db.delete(_db.products).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.printers).go();
      await _db.delete(_db.syncEvents).go();
      await _db.delete(_db.syncCursors).go();
      await _db.delete(_db.stores).go();

      // 2. Re-seed default clean store
      final now = DateTime.now();
      await _db.into(_db.stores).insert(
            StoresCompanion.insert(
              id: storeId,
              name: 'Toko UMKM POS',
              ownerName: const Value('Owner'),
              currency: const Value('IDR'),
              timezone: const Value('Asia/Jakarta'),
              language: const Value('id'),
              businessType: const Value('GENERAL'),
              customerEnabled: const Value(false),
              draftEnabled: const Value(true),
              splitPaymentEnabled: const Value(true),
              refundEnabled: const Value(true),
              cashRoundingEnabled: const Value(true),
              cashRoundingIncrement: const Value(100),
              cashRoundingMode: const Value('ROUND_NEAREST'),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
