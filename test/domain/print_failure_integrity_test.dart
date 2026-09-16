import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/constants/app_constants.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/printer_repository_impl.dart';
import 'package:mobile_pos/data/repositories/transaction_repository_impl.dart';
import 'package:mobile_pos/data/services/printer_service.dart';
import 'package:mobile_pos/domain/models/printer_device.dart';
import 'package:mobile_pos/domain/models/receipt_data.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class FailingPrinterTransport implements IPrinterTransport {
  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<List<BluetoothInfo>> getPairedDevices() async => [];

  @override
  Future<bool> connect(String macAddress) async {
    // Simulates printer turned off, out of range, or paper jam
    return false;
  }

  @override
  Future<bool> disconnect() async => true;

  @override
  Future<bool> isConnected() async => false;

  @override
  Future<bool> writeBytes(List<int> bytes) async => false;
}

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl trxRepo;
  late PrinterRepositoryImpl printerRepo;
  const storeId = AppConstants.defaultStoreId;
  const trxId = 'trx-integrity-001';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    trxRepo = TransactionRepositoryImpl(db);
    printerRepo = PrinterRepositoryImpl(db.printerDao);

    // Setup Store
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Kopi Kenangan UMKM',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'CRITICAL FINANCIAL INTEGRITY (PRD Bab 28 & Roadmap 10.6): '
      'Printer failure NEVER rolls back or alters COMPLETED transaction state',
      () async {
    final now = DateTime.now();

    // 1. Create and complete a valid transaction
    await trxRepo.createTransaction(
      transaction: TransactionsCompanion(
        id: const Value(trxId),
        storeId: const Value(storeId),
        transactionNumber: const Value('TRX-20260913-0001'),
        status: const Value('COMPLETED'),
        subtotal: const Value(40000),
        discountTotal: const Value(0),
        roundingAmount: const Value(0),
        total: const Value(40000),
        paidTotal: const Value(40000),
        createdAt: Value(now),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
      items: [
        TransactionItemsCompanion(
          id: const Value('item-001'),
          transactionId: const Value(trxId),
          productId: const Value('prod-001'),
          productNameSnapshot: const Value('Kopi Susu Regal'),
          quantity: const Value(2), // 2 units (raw, no scaling)
          unitPrice: const Value(20000),
          unitCostSnapshot: const Value(10000),
          subtotal: const Value(40000),
          total: const Value(40000),
          createdAt: Value(now),
        ),
      ],
      payment: PaymentsCompanion(
        id: const Value('pay-001'),
        transactionId: const Value(trxId),
        paymentMethodId: const Value('method-cash'),
        amount: const Value(40000),
        roundingAmount: const Value(0),
        status: const Value('COMPLETED'),
        paidAt: Value(now),
        createdAt: Value(now),
      ),
    );

    // Verify transaction completed in DB
    final savedTrx = await trxRepo.getTransaction(trxId);
    expect(savedTrx, isNotNull);
    expect(savedTrx!.status, equals('COMPLETED'));

    // 2. Setup Printer with FAILING transport (simulates printer out of paper / disconnected)
    final failingTransport = FailingPrinterTransport();
    final printerService = PrinterService(printerRepo, transport: failingTransport);

    final printer = PrinterDevice(
      id: 'printer-err-1',
      storeId: storeId,
      name: 'Disconnected Thermal 58',
      role: PrinterRole.receipt,
      addressReference: '00:00:00:00:00:00',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await printerRepo.savePrinter(printer);

    // 3. Build ReceiptData and attempt to print
    final receiptData = ReceiptData(
      transactionId: trxId,
      invoiceNumber: savedTrx.transactionNumber,
      transactionDate: savedTrx.completedAt ?? savedTrx.createdAt,
      cashierName: 'Kasir',
      storeHeader: const ReceiptHeader(storeName: 'Kopi Kenangan UMKM'),
      items: const [
        ReceiptItem(
          productName: 'Kopi Susu Regal',
          quantity: 2.0,
          unitPrice: 20000,
          subtotal: 40000,
          finalPrice: 40000,
        ),
      ],
      subtotal: 40000,
      grandTotal: 40000,
      payments: const [
        ReceiptPayment(method: 'Tunai', amount: 40000),
      ],
      amountPaid: 50000,
      changeAmount: 10000,
    );

    // 4. Execute print - MUST return false cleanly without throwing exception
    final printResult = await printerService.printReceipt(
      receiptData,
      targetPrinter: printer,
    );
    expect(printResult, isFalse);

    // 5. Test Auto-Print failure handling (PRD Ch. 28) - Must not throw
    await printerService.handleAutoPrintOnTransactionCompleted(receiptData);

    // 6. VERIFY STRICT FINANCIAL INTEGRITY:
    // Transaction status MUST remain COMPLETED
    final trxAfterPrintFailure = await trxRepo.getTransaction(trxId);
    expect(trxAfterPrintFailure!.status, equals('COMPLETED'));
    expect(trxAfterPrintFailure.total, equals(40000));
    expect(trxAfterPrintFailure.paidTotal, equals(40000));

    // Items must remain intact
    final itemsAfterPrint = await trxRepo.getTransactionItems(trxId);
    expect(itemsAfterPrint.length, equals(1));
    expect(itemsAfterPrint.first.productNameSnapshot, equals('Kopi Susu Regal'));

    // Payments must remain intact
    final paymentsAfterPrint = await db.paymentDao.getPaymentsByTransactionId(trxId);
    expect(paymentsAfterPrint.length, equals(1));
    expect(paymentsAfterPrint.first.status, equals('COMPLETED'));
  });

  test('MockPrinterTransport prints successfully when connected', () async {
    final mockTransport = MockPrinterTransport();
    final printerService = PrinterService(printerRepo, transport: mockTransport);

    final printer = PrinterDevice(
      id: 'printer-ok-1',
      storeId: storeId,
      name: 'Mock Thermal 58',
      role: PrinterRole.receipt,
      addressReference: '00:11:22:33:44:55',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await printerRepo.savePrinter(printer);

    final receiptData = ReceiptData(
      transactionId: 'trx-test',
      invoiceNumber: 'INV/001',
      transactionDate: DateTime(2026, 9, 13),
      storeHeader: const ReceiptHeader(storeName: 'Test Store'),
      items: const [],
      subtotal: 10000,
      grandTotal: 10000,
      payments: const [],
      amountPaid: 10000,
      changeAmount: 0,
    );

    final printResult = await printerService.printReceipt(
      receiptData,
      targetPrinter: printer,
    );

    expect(printResult, isTrue);
    expect(mockTransport.printedByteHistory, isNotEmpty);
  });
}
