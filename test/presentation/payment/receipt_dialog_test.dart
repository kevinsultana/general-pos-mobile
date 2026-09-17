import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/constants/app_constants.dart';
import 'package:mobile_pos/core/providers/database_providers.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/printer_repository_impl.dart';
import 'package:mobile_pos/data/services/printer_service.dart';
import 'package:mobile_pos/domain/models/printer_device.dart';
import 'package:mobile_pos/presentation/payment/widgets/receipt_dialog.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class FailingPrinterTransport implements IPrinterTransport {
  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<List<BluetoothInfo>> getPairedDevices() async => [];

  @override
  Future<bool> connect(String macAddress) async => false;

  @override
  Future<bool> disconnect() async => true;

  @override
  Future<bool> isConnected() async => false;

  @override
  Future<bool> writeBytes(List<int> bytes) async => false;
}

void main() {
  late AppDatabase db;
  const storeId = AppConstants.defaultStoreId;
  const trxId = 'trx-receipt-dialog-001';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Receipt Test Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    final now = DateTime.now();
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: trxId,
            storeId: storeId,
            transactionNumber: 'TRX-TEST-001',
            status: 'COMPLETED',
            subtotal: 25000,
            total: 25000,
            paidTotal: const Value(25000),
            createdAt: now,
            updatedAt: now,
            completedAt: Value(now),
          ),
        );

    await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'item-001',
            transactionId: trxId,
            productId: 'prod-001',
            productNameSnapshot: 'Kopi Susu Regal',
            quantity: 1,
            unitPrice: 25000,
            unitCostSnapshot: 10000,
            subtotal: 25000,
            total: 25000,
            createdAt: now,
          ),
        );

    await db.into(db.payments).insert(
          PaymentsCompanion.insert(
            id: 'pay-001',
            transactionId: trxId,
            paymentMethodId: 'method-cash',
            amount: 25000,
            status: 'COMPLETED',
            paidAt: Value(now),
            createdAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
      'ReceiptDialog: Displays Cetak Struk, switches to Coba Cetak Ulang on failure, with Lewati Struk / Selesai',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final failingTransport = FailingPrinterTransport();
    final printerRepo = PrinterRepositoryImpl(db.printerDao);
    final printerService = PrinterService(printerRepo, transport: failingTransport);

    // Save a disconnected printer
    await printerRepo.savePrinter(
      PrinterDevice(
        id: 'p-receipt-01',
        storeId: storeId,
        name: 'Thermal 58 Disconnected',
        role: PrinterRole.receipt,
        addressReference: '00:11:22:33:44:55',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          printerServiceProvider.overrideWithValue(printerService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(transactionId: trxId),
          ),
        ),
      ),
    );

    // Wait for data load
    await tester.pumpAndSettle();

    // 1. Verify initial UI elements
    expect(find.text('PEMBAYARAN BERHASIL'), findsOneWidget);
    expect(find.text('Cetak Struk'), findsOneWidget);
    expect(find.text('Lewati Struk / Selesai'), findsOneWidget);
    expect(find.text('Transaksi Baru'), findsOneWidget);

    // 2. Tap "Cetak Struk"
    await tester.tap(find.text('Cetak Struk'));
    await tester.pump(); // Start async print

    // Wait for async print failure
    await tester.pumpAndSettle();

    // 3. Verify failure state:
    // Should display warning banner and "Coba Cetak Ulang" button
    expect(find.text('Gagal Mencetak Struk'), findsOneWidget);
    expect(find.text('Coba Cetak Ulang'), findsOneWidget);
    expect(find.text('Lewati Struk / Selesai'), findsOneWidget);

    // 4. Tap "Lewati Struk / Selesai"
    await tester.tap(find.text('Lewati Struk / Selesai'));
    await tester.pumpAndSettle();
  });
}
