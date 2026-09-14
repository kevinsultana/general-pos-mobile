import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/printer_repository_impl.dart';
import 'package:mobile_pos/domain/models/printer_device.dart';

void main() {
  late AppDatabase db;
  late PrinterRepositoryImpl printerRepo;
  const storeId = 'store-test-printer';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    printerRepo = PrinterRepositoryImpl(db.printerDao);

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Printer Test Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('Printer Repository CRUD, paper size encoding, and role queries', () async {
    final now = DateTime.now();

    // 1. Save Cashier Receipt Printer (58mm)
    final cashierPrinter = PrinterDevice(
      id: 'printer-c1',
      storeId: storeId,
      name: 'Cashier Thermal 58',
      role: PrinterRole.receipt,
      connectionType: PrinterConnectionType.bluetooth,
      addressReference: '00:11:22:33:44:55',
      paperSize: PrinterPaperSize.mm58,
      receiptCopies: 2,
      autoPrint: true,
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    await printerRepo.savePrinter(cashierPrinter);

    // 2. Save Kitchen Printer (80mm)
    final kitchenPrinter = PrinterDevice(
      id: 'printer-k1',
      storeId: storeId,
      name: 'Kitchen Impact 80',
      role: PrinterRole.kitchen,
      connectionType: PrinterConnectionType.bluetooth,
      addressReference: 'AA:BB:CC:DD:EE:FF',
      paperSize: PrinterPaperSize.mm80,
      kitchenCopies: 1,
      autoPrint: false,
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    await printerRepo.savePrinter(kitchenPrinter);

    // 3. Query all printers
    final all = await printerRepo.getAllPrinters(storeId);
    expect(all.length, equals(2));

    // 4. Query by ID and verify paper size decoded accurately
    final fetchedC1 = await printerRepo.getPrinterById('printer-c1');
    expect(fetchedC1, isNotNull);
    expect(fetchedC1!.name, equals('Cashier Thermal 58'));
    expect(fetchedC1.paperSize, equals(PrinterPaperSize.mm58));
    expect(fetchedC1.receiptCopies, equals(2));
    expect(fetchedC1.autoPrint, isTrue);

    final fetchedK1 = await printerRepo.getPrinterById('printer-k1');
    expect(fetchedK1, isNotNull);
    expect(fetchedK1!.paperSize, equals(PrinterPaperSize.mm80));
    expect(fetchedK1.role, equals(PrinterRole.kitchen));

    // 5. Query active printers by role
    final receiptPrinters = await printerRepo.getActivePrintersByRole(
      storeId,
      PrinterRole.receipt,
    );
    expect(receiptPrinters.length, equals(1));
    expect(receiptPrinters.first.id, equals('printer-c1'));

    final kitchenPrinters = await printerRepo.getActivePrintersByRole(
      storeId,
      PrinterRole.kitchen,
    );
    expect(kitchenPrinters.length, equals(1));
    expect(kitchenPrinters.first.id, equals('printer-k1'));

    // 6. Update printer configuration
    final updatedC1 = fetchedC1.copyWith(
      name: 'Cashier Upgraded 80mm',
      paperSize: PrinterPaperSize.mm80,
      receiptCopies: 1,
    );
    await printerRepo.savePrinter(updatedC1);

    final reloaded = await printerRepo.getPrinterById('printer-c1');
    expect(reloaded!.name, equals('Cashier Upgraded 80mm'));
    expect(reloaded.paperSize, equals(PrinterPaperSize.mm80));
    expect(reloaded.receiptCopies, equals(1));

    // 7. Delete printer
    await printerRepo.deletePrinter('printer-k1');
    final afterDelete = await printerRepo.getAllPrinters(storeId);
    expect(afterDelete.length, equals(1));
    expect(afterDelete.first.id, equals('printer-c1'));
  });
}
