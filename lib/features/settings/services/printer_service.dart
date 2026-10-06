import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/currency_formatter.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  PrinterService._init();

  String? _connectedDeviceName;
  bool get isConnected => _connectedDeviceName != null;
  String? get connectedDeviceName => _connectedDeviceName;

  void setConnectedDevice(String? name) {
    _connectedDeviceName = name;
  }

  /// Format Struk Kasir Standar 58mm / 32 Karakter
  String generateReceiptText({
    required String storeName,
    required TransactionModel transaction,
  }) {
    final buffer = StringBuffer();
    final date = DateTime.tryParse(transaction.createdAt) ?? DateTime.now();
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(date);

    buffer.writeln('================================');
    buffer.writeln(_centerText(storeName.toUpperCase(), 32));
    buffer.writeln(_centerText('OmniPOS Kasir Pintar', 32));
    buffer.writeln('================================');
    buffer.writeln('No. Struk : ${transaction.receiptNumber}');
    buffer.writeln('Waktu     : $dateFormatted');
    buffer.writeln('Pelanggan : ${transaction.customerName ?? "Umum"}');
    buffer.writeln('--------------------------------');

    for (final item in transaction.items) {
      final name = item.productName;
      final line1 = '${item.quantity}x $name';
      final priceStr = CurrencyFormatter.format(item.subtotal);
      buffer.writeln(_formatTwoColumn(line1, priceStr, 32));

      if (item.notes != null && item.notes!.isNotEmpty) {
        buffer.writeln('  Catatan: ${item.notes}');
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln(_formatTwoColumn('TOTAL :', CurrencyFormatter.format(transaction.totalAmount), 32));
    buffer.writeln(_formatTwoColumn('TUNAI :', CurrencyFormatter.format(transaction.cashPaid), 32));
    buffer.writeln(_formatTwoColumn('KEMBALI :', CurrencyFormatter.format(transaction.changeAmount), 32));
    buffer.writeln('================================');
    buffer.writeln(_centerText('Terima Kasih atas Kunjungan Anda', 32));
    buffer.writeln(_centerText('Powered by OmniPOS', 32));
    buffer.writeln('\n\n');

    return buffer.toString();
  }

  Future<bool> printReceipt({
    required String storeName,
    required TransactionModel transaction,
  }) async {
    final text = generateReceiptText(storeName: storeName, transaction: transaction);
    debugPrint('--- CETAK STRUK THERMAL 58MM ---');
    debugPrint(text);
    return true;
  }

  String _centerText(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final leftPadding = (width - text.length) ~/ 2;
    return ' ' * leftPadding + text;
  }

  String _formatTwoColumn(String left, String right, int width) {
    final totalLen = left.length + right.length;
    if (totalLen >= width) {
      return '$left $right';
    }
    final space = ' ' * (width - totalLen);
    return '$left$space$right';
  }
}
