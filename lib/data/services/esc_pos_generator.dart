import 'dart:convert';
import 'package:intl/intl.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/models/printer_device.dart';
import '../../domain/models/receipt_data.dart';

class EscPosGenerator {
  // ESC/POS Command Constants
  static const List<int> cmdInit = [0x1B, 0x40];
  static const List<int> cmdAlignLeft = [0x1B, 0x61, 0x00];
  static const List<int> cmdAlignCenter = [0x1B, 0x61, 0x01];
  static const List<int> cmdAlignRight = [0x1B, 0x61, 0x02];

  static const List<int> cmdBoldOn = [0x1B, 0x45, 0x01];
  static const List<int> cmdBoldOff = [0x1B, 0x45, 0x00];

  static const List<int> cmdUnderlineOn = [0x1B, 0x2D, 0x01];
  static const List<int> cmdUnderlineOff = [0x1B, 0x2D, 0x00];

  static const List<int> cmdTextNormal = [0x1D, 0x21, 0x00];
  static const List<int> cmdTextDoubleHeight = [0x1D, 0x21, 0x01];
  static const List<int> cmdTextDoubleWidth = [0x1D, 0x21, 0x10];
  static const List<int> cmdTextLarge = [0x1D, 0x21, 0x11]; // Double width + height

  static const List<int> cmdCut = [0x1D, 0x56, 0x42, 0x00]; // GS V B 0

  static List<int> cmdFeed(int lines) => [0x1B, 0x64, lines.clamp(1, 10)];

  /// Generates the complete ESC/POS byte sequence for a receipt
  static List<int> generateReceipt(
    ReceiptData receipt, {
    PrinterPaperSize paperSize = PrinterPaperSize.mm58,
  }) {
    final bytes = <int>[];
    final maxChars = paperSize.maxCharsPerLine;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Initialize printer
    bytes.addAll(cmdInit);

    // 1. Store Header
    bytes.addAll(cmdAlignCenter);
    bytes.addAll(cmdBoldOn);
    bytes.addAll(cmdTextLarge);
    bytes.addAll(_encodeText(receipt.storeHeader.storeName));
    bytes.addAll(_lineBreak());

    bytes.addAll(cmdTextNormal);
    bytes.addAll(cmdBoldOff);

    if (receipt.storeHeader.storeAddress != null &&
        receipt.storeHeader.storeAddress!.isNotEmpty) {
      bytes.addAll(_encodeText(receipt.storeHeader.storeAddress!));
      bytes.addAll(_lineBreak());
    }

    if (receipt.storeHeader.storePhone != null &&
        receipt.storeHeader.storePhone!.isNotEmpty) {
      bytes.addAll(_encodeText('Telp: ${receipt.storeHeader.storePhone!}'));
      bytes.addAll(_lineBreak());
    }

    if (receipt.storeHeader.headerMessage != null &&
        receipt.storeHeader.headerMessage!.isNotEmpty) {
      bytes.addAll(_encodeText(receipt.storeHeader.headerMessage!));
      bytes.addAll(_lineBreak());
    }

    // Divider
    bytes.addAll(_divider(maxChars));

    // 2. Transaction Metadata
    bytes.addAll(cmdAlignLeft);
    bytes.addAll(_twoColumns(
      'No: ${receipt.invoiceNumber}',
      dateFormat.format(receipt.transactionDate),
      maxChars,
    ));

    if (receipt.cashierName != null || receipt.customerName != null) {
      final cashier = receipt.cashierName != null ? 'Kasir: ${receipt.cashierName}' : '';
      final customer = receipt.customerName != null ? 'Plggn: ${receipt.customerName}' : '';
      bytes.addAll(_twoColumns(cashier, customer, maxChars));
    }

    // Divider
    bytes.addAll(_divider(maxChars));

    // 3. Line Items
    for (final item in receipt.items) {
      // Product & Variant Name (Left)
      bytes.addAll(cmdAlignLeft);
      bytes.addAll(_encodeText(item.displayName));
      bytes.addAll(_lineBreak());

      // Qty x Price on left, Subtotal on right
      final qtyStr = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(2);
      final priceStr = CurrencyFormatter.format(item.unitPrice);
      final subtotalStr = CurrencyFormatter.format(item.subtotal);

      bytes.addAll(_twoColumns('  $qtyStr x $priceStr', subtotalStr, maxChars));

      // Item discount (if any)
      if (item.discountAmount > 0) {
        final discStr = '-${CurrencyFormatter.format(item.discountAmount)}';
        bytes.addAll(_twoColumns('  (Diskon Item)', discStr, maxChars));
      }

      // Item note (if any)
      if (item.note != null && item.note!.isNotEmpty) {
        bytes.addAll(cmdAlignLeft);
        bytes.addAll(_encodeText('  * ${item.note!}'));
        bytes.addAll(_lineBreak());
      }
    }

    // Divider
    bytes.addAll(_divider(maxChars));

    // 4. Financial Totals
    bytes.addAll(_twoColumns(
      'Subtotal',
      CurrencyFormatter.format(receipt.subtotal),
      maxChars,
    ));

    if (receipt.orderDiscount > 0) {
      bytes.addAll(_twoColumns(
        'Diskon Transaksi',
        '-${CurrencyFormatter.format(receipt.orderDiscount)}',
        maxChars,
      ));
    }

    if (receipt.cashRounding != 0) {
      final sign = receipt.cashRounding > 0 ? '+' : '';
      bytes.addAll(_twoColumns(
        'Pembulatan Tunai',
        '$sign${CurrencyFormatter.format(receipt.cashRounding)}',
        maxChars,
      ));
    }

    // Grand Total (Bold)
    bytes.addAll(cmdBoldOn);
    bytes.addAll(_twoColumns(
      'TOTAL',
      CurrencyFormatter.format(receipt.grandTotal),
      maxChars,
    ));
    bytes.addAll(cmdBoldOff);

    // Divider
    bytes.addAll(_divider(maxChars, char: '-'));

    // 5. Payments
    for (final payment in receipt.payments) {
      bytes.addAll(_twoColumns(
        'Bayar (${payment.method})',
        CurrencyFormatter.format(payment.amount),
        maxChars,
      ));
    }

    if (receipt.changeAmount > 0) {
      bytes.addAll(_twoColumns(
        'Kembali',
        CurrencyFormatter.format(receipt.changeAmount),
        maxChars,
      ));
    }

    // Divider
    bytes.addAll(_divider(maxChars));

    // 6. Footer Message
    bytes.addAll(cmdAlignCenter);
    final footer = receipt.footerMessage ?? 'Terima kasih atas kunjungan Anda!';
    bytes.addAll(_encodeText(footer));
    bytes.addAll(_lineBreak());

    // Barcode of invoice number
    bytes.addAll(_barcodeCode128(receipt.invoiceNumber));

    // Feed and Cut
    bytes.addAll(cmdFeed(3));
    bytes.addAll(cmdCut);

    return bytes;
  }

  /// Generates the ESC/POS byte sequence for a kitchen order ticket (PRD Bab 30)
  static List<int> generateKitchenTicket(
    KitchenTicketData ticket, {
    PrinterPaperSize paperSize = PrinterPaperSize.mm58,
  }) {
    final bytes = <int>[];
    final maxChars = paperSize.maxCharsPerLine;
    final timeFormat = DateFormat('HH:mm:ss (dd/MM)');

    bytes.addAll(cmdInit);

    // Header: TIKET DAPUR
    bytes.addAll(cmdAlignCenter);
    bytes.addAll(cmdBoldOn);
    bytes.addAll(cmdTextLarge);
    bytes.addAll(_encodeText('*** TIKET DAPUR ***'));
    bytes.addAll(_lineBreak());
    bytes.addAll(cmdTextNormal);
    bytes.addAll(cmdBoldOff);

    bytes.addAll(_divider(maxChars, char: '='));

    // Order Info
    bytes.addAll(cmdAlignLeft);
    bytes.addAll(_twoColumns(
      'No: ${ticket.invoiceNumber}',
      timeFormat.format(ticket.orderTime),
      maxChars,
    ));

    if (ticket.tableOrCustomer != null && ticket.tableOrCustomer!.isNotEmpty) {
      bytes.addAll(cmdBoldOn);
      bytes.addAll(_encodeText('Meja / Pelanggan: ${ticket.tableOrCustomer!}'));
      bytes.addAll(_lineBreak());
      bytes.addAll(cmdBoldOff);
    }

    if (ticket.cashierName != null && ticket.cashierName!.isNotEmpty) {
      bytes.addAll(_encodeText('Kasir: ${ticket.cashierName!}'));
      bytes.addAll(_lineBreak());
    }

    bytes.addAll(_divider(maxChars, char: '='));

    // Items list for kitchen (Big Quantity)
    for (final item in ticket.items) {
      final qtyStr = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(1);

      bytes.addAll(cmdBoldOn);
      bytes.addAll(cmdTextDoubleHeight);
      bytes.addAll(_encodeText('[$qtyStr x] ${item.displayName}'));
      bytes.addAll(_lineBreak());
      bytes.addAll(cmdTextNormal);
      bytes.addAll(cmdBoldOff);

      if (item.note != null && item.note!.isNotEmpty) {
        bytes.addAll(_encodeText('  -> Catatan: ${item.note!}'));
        bytes.addAll(_lineBreak());
      }
      bytes.addAll(_lineBreak());
    }

    if (ticket.orderNote != null && ticket.orderNote!.isNotEmpty) {
      bytes.addAll(_divider(maxChars, char: '-'));
      bytes.addAll(cmdBoldOn);
      bytes.addAll(_encodeText('Catatan Pesanan: ${ticket.orderNote!}'));
      bytes.addAll(_lineBreak());
      bytes.addAll(cmdBoldOff);
    }

    bytes.addAll(_divider(maxChars, char: '='));

    bytes.addAll(cmdFeed(3));
    bytes.addAll(cmdCut);

    return bytes;
  }

  /// Generates a test print slip to verify printer connection and alignment
  static List<int> generateTestPrint({
    PrinterPaperSize paperSize = PrinterPaperSize.mm58,
  }) {
    final bytes = <int>[];
    final maxChars = paperSize.maxCharsPerLine;
    final nowStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    bytes.addAll(cmdInit);
    bytes.addAll(cmdAlignCenter);
    bytes.addAll(cmdBoldOn);
    bytes.addAll(cmdTextLarge);
    bytes.addAll(_encodeText('UMKM POS'));
    bytes.addAll(_lineBreak());
    bytes.addAll(cmdTextNormal);
    bytes.addAll(_encodeText('UJI COBA PRINTER'));
    bytes.addAll(_lineBreak());
    bytes.addAll(cmdBoldOff);

    bytes.addAll(_divider(maxChars, char: '='));

    bytes.addAll(cmdAlignLeft);
    bytes.addAll(_twoColumns('Status Printer', 'TERHUBUNG (OK)', maxChars));
    bytes.addAll(_twoColumns('Ukuran Kertas', paperSize.displayName, maxChars));
    bytes.addAll(_twoColumns('Lebar Baris', '$maxChars Karakter', maxChars));
    bytes.addAll(_twoColumns('Waktu Uji', nowStr, maxChars));

    bytes.addAll(_divider(maxChars, char: '-'));

    bytes.addAll(cmdAlignCenter);
    bytes.addAll(cmdBoldOn);
    bytes.addAll(_encodeText('Printer thermal Anda siap digunakan!'));
    bytes.addAll(_lineBreak());
    bytes.addAll(cmdBoldOff);

    bytes.addAll(cmdFeed(3));
    bytes.addAll(cmdCut);

    return bytes;
  }

  // --- Helper Methods ---

  static List<int> _encodeText(String text) {
    // Standard Latin-1 or ASCII bytes for thermal receipt printing
    return latin1.encode(text);
  }

  static List<int> _lineBreak() => [0x0A];

  static List<int> _divider(int maxChars, {String char = '-'}) {
    final line = char * maxChars;
    final bytes = <int>[];
    bytes.addAll(cmdAlignLeft);
    bytes.addAll(_encodeText(line));
    bytes.addAll(_lineBreak());
    return bytes;
  }

  /// Formats two strings aligned to the left and right edges with padding
  static List<int> _twoColumns(String left, String right, int maxChars) {
    final bytes = <int>[];
    bytes.addAll(cmdAlignLeft);

    final leftLen = left.length;
    final rightLen = right.length;
    final totalLen = leftLen + rightLen;

    if (totalLen >= maxChars) {
      // If combined length is too long, print on separate lines to avoid truncating crucial metadata (e.g. invoice numbers)
      final availableLeft = maxChars - rightLen - 1;
      if (availableLeft > 4 && leftLen <= availableLeft) {
        final spaces = ' ' * (maxChars - leftLen - rightLen);
        bytes.addAll(_encodeText('$left$spaces$right'));
      } else {
        bytes.addAll(_encodeText(left));
        bytes.addAll(_lineBreak());
        bytes.addAll(cmdAlignRight);
        bytes.addAll(_encodeText(right));
      }
    } else {
      final spaces = ' ' * (maxChars - totalLen);
      bytes.addAll(_encodeText('$left$spaces$right'));
    }

    bytes.addAll(_lineBreak());
    return bytes;
  }

  /// Generates CODE 128 barcode commands for ESC/POS
  static List<int> _barcodeCode128(String data) {
    if (data.isEmpty) return [];

    final bytes = <int>[];
    bytes.addAll(cmdAlignCenter);
    // Set barcode width (2 dots)
    bytes.addAll([0x1D, 0x77, 0x02]);
    // Set barcode height (50 dots)
    bytes.addAll([0x1D, 0x68, 50]);
    // Print HRI text below barcode
    bytes.addAll([0x1D, 0x48, 0x02]);

    final encodedData = ascii.encode(data);
    // GS k 73 [len] [data...]
    bytes.addAll([0x1D, 0x6B, 73, encodedData.length]);
    bytes.addAll(encodedData);
    bytes.addAll(_lineBreak());

    return bytes;
  }
}
