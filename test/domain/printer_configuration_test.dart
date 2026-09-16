import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/local/cloud_database.dart';
import 'package:mobile_pos/data/services/api_client.dart';
import 'package:mobile_pos/data/services/cloud_sync_service.dart';
import 'package:mobile_pos/domain/models/printer_device.dart';

void main() {
  group('P4.3 Printer Configuration JSON Compatibility Tests', () {
    test('decodeConfiguration parses null, empty string, Map, and JSON string safely', () {
      expect(PrinterDevice.decodeConfiguration(null), isEmpty);
      expect(PrinterDevice.decodeConfiguration(''), isEmpty);
      expect(PrinterDevice.decodeConfiguration('  '), isEmpty);
      expect(PrinterDevice.decodeConfiguration('invalid json string'), isEmpty);

      final fromMap = PrinterDevice.decodeConfiguration({
        'charsPerLine': 48,
        'baudRate': 9600,
        'ip': '192.168.1.100',
      });
      expect(fromMap['charsPerLine'], equals(48));
      expect(fromMap['baudRate'], equals(9600));
      expect(fromMap['ip'], equals('192.168.1.100'));

      final fromJsonStr = PrinterDevice.decodeConfiguration(
        '{"charsPerLine":32,"cutPaper":true,"drawerPin":2}',
      );
      expect(fromJsonStr['charsPerLine'], equals(32));
      expect(fromJsonStr['cutPaper'], isTrue);
      expect(fromJsonStr['drawerPin'], equals(2));
    });

    test('decodePaperSize handles Map, JSON string, direct strings, and null without error', () {
      expect(PrinterDevice.decodePaperSize(null), equals(PrinterPaperSize.mm58));
      expect(PrinterDevice.decodePaperSize(''), equals(PrinterPaperSize.mm58));
      expect(PrinterDevice.decodePaperSize({}), equals(PrinterPaperSize.mm58));

      // From Map
      expect(
        PrinterDevice.decodePaperSize({'paperSize': 'PAPER_80MM'}),
        equals(PrinterPaperSize.mm80),
      );
      expect(
        PrinterDevice.decodePaperSize({'paperSize': '80mm'}),
        equals(PrinterPaperSize.mm80),
      );
      expect(
        PrinterDevice.decodePaperSize({'paperSize': 'PAPER_58MM'}),
        equals(PrinterPaperSize.mm58),
      );

      // From JSON String
      expect(
        PrinterDevice.decodePaperSize('{"paperSize":"PAPER_80MM"}'),
        equals(PrinterPaperSize.mm80),
      );
      expect(
        PrinterDevice.decodePaperSize('{"paperSize":"PAPER_58MM"}'),
        equals(PrinterPaperSize.mm58),
      );

      // From raw paperSize string
      expect(
        PrinterDevice.decodePaperSize('PAPER_80MM'),
        equals(PrinterPaperSize.mm80),
      );
      expect(
        PrinterDevice.decodePaperSize('80MM'),
        equals(PrinterPaperSize.mm80),
      );
      expect(
        PrinterDevice.decodePaperSize('58MM'),
        equals(PrinterPaperSize.mm58),
      );
    });

    test('encodeConfiguration preserves customConfiguration and updates paperSize', () {
      final now = DateTime.now();
      final printer = PrinterDevice(
        id: 'printer-1',
        storeId: 'store-1',
        name: 'Kasir Utama',
        paperSize: PrinterPaperSize.mm80,
        customConfiguration: const {
          'charsPerLine': 48,
          'baudRate': 115200,
          'cutPaper': true,
        },
        createdAt: now,
        updatedAt: now,
      );

      final encoded = printer.encodeConfiguration();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['paperSize'], equals('PAPER_80MM'));
      expect(decoded['charsPerLine'], equals(48));
      expect(decoded['baudRate'], equals(115200));
      expect(decoded['cutPaper'], isTrue);

      // Changing paperSize via copyWith updates encoded paperSize while preserving other configs
      final updated = printer.copyWith(paperSize: PrinterPaperSize.mm58);
      final updatedDecoded = jsonDecode(updated.encodeConfiguration()) as Map<String, dynamic>;
      expect(updatedDecoded['paperSize'], equals('PAPER_58MM'));
      expect(updatedDecoded['charsPerLine'], equals(48));
      expect(updatedDecoded['baudRate'], equals(115200));
    });

    group('Inbound Sync Ingestion for Printers', () {
      late AppDatabase db;
      late CloudDatabase cloudDb;
      late CloudSyncService syncService;

      const storeId = 'store-test-printer-sync';

      setUpAll(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      });

      setUp(() async {
        db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
        cloudDb = CloudDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
        final tokenStorage = TokenStorage(const FlutterSecureStorage());
        final apiClient = ApiClient(tokenStorage);

        syncService = CloudSyncService(
          cloudDb.cloudSyncEventDao,
          apiClient,
          tokenStorage,
          db,
        );
      });

      tearDown(() async {
        await db.close();
        await cloudDb.close();
      });

      test('entityTypeFor maps printer operations to Printer', () {
        expect(syncService.entityTypeFor('CREATE_PRINTER'), equals('Printer'));
        expect(syncService.entityTypeFor('UPDATE_PRINTER'), equals('Printer'));
        expect(syncService.entityTypeFor('DELETE_PRINTER'), equals('Printer'));
      });

      test('Inbound CREATE_PRINTER upserts printer with robust JSON configuration', () async {
        const printerId = 'prn-sync-101';
        await syncService.dispatchOperationForTesting(
          storeId,
          'CREATE_PRINTER',
          {
            'id': printerId,
            'name': 'Printer Dapur Cloud',
            'connectionType': 'NETWORK',
            'addressReference': '192.168.1.50',
            'paperSize': 'PAPER_80MM',
            'role': 'KITCHEN',
            'receiptCopies': 1,
            'kitchenCopies': 2,
            'autoPrint': true,
            'configuration': {
              'paperSize': 'PAPER_80MM',
              'ipAddress': '192.168.1.50',
              'port': 9100,
              'cutPaper': true,
            },
          },
        );

        final saved = await db.printerDao.getPrinterById(printerId);
        expect(saved, isNotNull);
        expect(saved!.name, equals('Printer Dapur Cloud'));
        expect(saved.role, equals('KITCHEN'));
        expect(saved.connectionType, equals('NETWORK'));
        expect(saved.kitchenCopies, equals(2));

        // Verify configuration JSON parsed correctly
        final configMap = jsonDecode(saved.configuration!) as Map<String, dynamic>;
        expect(configMap['paperSize'], equals('PAPER_80MM'));
        expect(configMap['ipAddress'], equals('192.168.1.50'));
        expect(configMap['port'], equals(9100));
        expect(configMap['cutPaper'], isTrue);

        // Verify inbound DELETE_PRINTER deletes printer
        await syncService.dispatchOperationForTesting(
          storeId,
          'DELETE_PRINTER',
          {'id': printerId},
        );
        final afterDelete = await db.printerDao.getPrinterById(printerId);
        expect(afterDelete, isNull);
      });
    });
  });
}
