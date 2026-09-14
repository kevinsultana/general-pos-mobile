import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/services/esc_pos_generator.dart';
import 'package:mobile_pos/domain/models/printer_device.dart';
import 'package:mobile_pos/domain/models/receipt_data.dart';

void main() {
  group('EscPosGenerator Tests', () {
    late ReceiptData sampleReceipt;
    late KitchenTicketData sampleKitchenTicket;

    setUp(() {
      sampleReceipt = ReceiptData(
        transactionId: 'trx-12345',
        invoiceNumber: 'INV/2026/09/001',
        transactionDate: DateTime(2026, 9, 13, 14, 30),
        cashierName: 'Budi',
        customerName: 'Ahmad Pelanggan',
        storeHeader: const ReceiptHeader(
          storeName: 'WARUNG KOPI UMKM',
          storeAddress: 'Jl. Merdeka No. 45, Jakarta',
          storePhone: '08123456789',
          headerMessage: 'Struk Resmi Pembelian',
        ),
        items: const [
          ReceiptItem(
            productName: 'Kopi Susu Gula Aren',
            variantName: 'Less Sugar',
            quantity: 2.0,
            unitPrice: 18000,
            subtotal: 36000,
            discountAmount: 0,
            finalPrice: 36000,
          ),
          ReceiptItem(
            productName: 'Roti Bakar Cokelat',
            quantity: 1.0,
            unitPrice: 15000,
            subtotal: 15000,
            discountAmount: 2000,
            finalPrice: 13000,
          ),
        ],
        subtotal: 51000,
        orderDiscount: 2000,
        cashRounding: 100,
        grandTotal: 49100,
        payments: const [
          ReceiptPayment(
            method: 'Tunai',
            amount: 50000,
          ),
        ],
        amountPaid: 50000,
        changeAmount: 900,
        footerMessage: 'Terima kasih atas kunjungan Anda!',
      );

      sampleKitchenTicket = KitchenTicketData(
        orderId: 'trx-12345',
        invoiceNumber: 'INV/2026/09/001',
        orderTime: DateTime(2026, 9, 13, 14, 30),
        tableOrCustomer: 'Meja 5',
        cashierName: 'Budi',
        items: const [
          ReceiptItem(
            productName: 'Kopi Susu Gula Aren',
            variantName: 'Less Sugar',
            quantity: 2.0,
            unitPrice: 18000,
            subtotal: 36000,
            finalPrice: 36000,
          ),
          ReceiptItem(
            productName: 'Roti Bakar Cokelat',
            quantity: 1.0,
            unitPrice: 15000,
            subtotal: 15000,
            finalPrice: 13000,
          ),
        ],
      );
    });

    test('generateReceipt 58mm (32 columns) generates valid non-empty byte stream', () {
      final bytes = EscPosGenerator.generateReceipt(
        sampleReceipt,
        paperSize: PrinterPaperSize.mm58,
      );

      expect(bytes, isNotEmpty);
      // Contains ESC @ (Initialize printer: 0x1B, 0x40)
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));

      // Contains GS V (Paper cut command: 0x1D, 0x56)
      expect(bytes.contains(0x1D), isTrue);
      expect(bytes.contains(0x56), isTrue);
    });

    test('generateReceipt 80mm (48 columns) generates valid non-empty byte stream', () {
      final bytes = EscPosGenerator.generateReceipt(
        sampleReceipt,
        paperSize: PrinterPaperSize.mm80,
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));
      expect(bytes.contains(0x1D), isTrue);
      expect(bytes.contains(0x56), isTrue);
    });

    test('generateKitchenTicket creates ticket with order items and cut command', () {
      final bytes = EscPosGenerator.generateKitchenTicket(
        sampleKitchenTicket,
        paperSize: PrinterPaperSize.mm58,
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));
      // Cut command
      expect(bytes.contains(0x1D), isTrue);
      expect(bytes.contains(0x56), isTrue);
    });

    test('generateTestPrint generates test print content with alignment and divider', () {
      final bytes58 = EscPosGenerator.generateTestPrint(
        paperSize: PrinterPaperSize.mm58,
      );
      expect(bytes58, isNotEmpty);
      expect(bytes58[0], equals(0x1B));
      expect(bytes58[1], equals(0x40));
      expect(bytes58.contains(0x1D), isTrue);

      final bytes80 = EscPosGenerator.generateTestPrint(
        paperSize: PrinterPaperSize.mm80,
      );
      expect(bytes80, isNotEmpty);
      expect(bytes80[0], equals(0x1B));
      expect(bytes80[1], equals(0x40));
      expect(bytes80.contains(0x1D), isTrue);
    });
  });
}
