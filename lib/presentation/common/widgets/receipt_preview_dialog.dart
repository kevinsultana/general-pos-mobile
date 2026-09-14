import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/receipt_data.dart';

class ReceiptPreviewDialog extends ConsumerStatefulWidget {
  final ReceiptData receipt;
  final VoidCallback? onPrintSuccess;

  const ReceiptPreviewDialog({
    super.key,
    required this.receipt,
    this.onPrintSuccess,
  });

  static Future<void> show(
    BuildContext context,
    ReceiptData receipt, {
    VoidCallback? onPrintSuccess,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ReceiptPreviewDialog(
        receipt: receipt,
        onPrintSuccess: onPrintSuccess,
      ),
    );
  }

  @override
  ConsumerState<ReceiptPreviewDialog> createState() =>
      _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends ConsumerState<ReceiptPreviewDialog> {
  bool _isPrinting = false;

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    final printerService = ref.read(printerServiceProvider);

    try {
      final success = await printerService.printReceipt(widget.receipt);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Struk berhasil dikirim ke printer thermal'),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onPrintSuccess?.call();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal mencetak: Printer tidak terhubung atau belum dikonfigurasi. Periksa Pengaturan Printer.',
              ),
              backgroundColor: AppColors.danger,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Pratinjau Struk Belanja',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Thermal Paper Simulated Area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Store Name & Header
                      Text(
                        receipt.storeHeader.storeName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (receipt.storeHeader.storeAddress != null &&
                          receipt.storeHeader.storeAddress!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            receipt.storeHeader.storeAddress!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      if (receipt.storeHeader.storePhone != null &&
                          receipt.storeHeader.storePhone!.isNotEmpty)
                        Text(
                          'Telp: ${receipt.storeHeader.storePhone!}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),

                      const _DashedLine(),

                      // Metadata
                      _rowMono(
                        'No: ${receipt.invoiceNumber}',
                        dateFormat.format(receipt.transactionDate),
                      ),
                      if (receipt.cashierName != null || receipt.customerName != null)
                        _rowMono(
                          receipt.cashierName != null
                              ? 'Kasir: ${receipt.cashierName}'
                              : '',
                          receipt.customerName != null
                              ? 'Plggn: ${receipt.customerName}'
                              : '',
                        ),

                      const _DashedLine(),

                      // Items
                      ...receipt.items.map((item) {
                        final qtyStr = item.quantity % 1 == 0
                            ? item.quantity.toInt().toString()
                            : item.quantity.toStringAsFixed(1);
                        final priceStr = CurrencyFormatter.format(item.unitPrice);
                        final subtotalStr = CurrencyFormatter.format(item.subtotal);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              _rowMono('  $qtyStr x $priceStr', subtotalStr),
                              if (item.discountAmount > 0)
                                _rowMono(
                                  '  (Diskon Item)',
                                  '-${CurrencyFormatter.format(item.discountAmount)}',
                                  color: Colors.red.shade700,
                                ),
                              if (item.note != null && item.note!.isNotEmpty)
                                Text(
                                  '  * ${item.note!}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                      const _DashedLine(),

                      // Totals
                      _rowMono(
                        'Subtotal',
                        CurrencyFormatter.format(receipt.subtotal),
                      ),
                      if (receipt.orderDiscount > 0)
                        _rowMono(
                          'Diskon Transaksi',
                          '-${CurrencyFormatter.format(receipt.orderDiscount)}',
                          color: Colors.red.shade700,
                        ),
                      if (receipt.cashRounding != 0)
                        _rowMono(
                          'Pembulatan Tunai',
                          '${receipt.cashRounding > 0 ? '+' : ''}${CurrencyFormatter.format(receipt.cashRounding)}',
                        ),

                      const SizedBox(height: 4),
                      _rowMono(
                        'TOTAL',
                        CurrencyFormatter.format(receipt.grandTotal),
                        isBold: true,
                        fontSize: 14,
                      ),

                      const _DashedLine(),

                      // Payments
                      ...receipt.payments.map((p) => _rowMono(
                            'Bayar (${p.method})',
                            CurrencyFormatter.format(p.amount),
                          )),
                      if (receipt.changeAmount > 0)
                        _rowMono(
                          'Kembali',
                          CurrencyFormatter.format(receipt.changeAmount),
                          isBold: true,
                        ),

                      const _DashedLine(),

                      // Footer & Barcode
                      Text(
                        receipt.footerMessage ??
                            'Terima kasih atas kunjungan Anda!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Barcode of invoice number
                      Center(
                        child: SizedBox(
                          height: 44,
                          width: 180,
                          child: BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: receipt.invoiceNumber,
                            drawText: true,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isPrinting ? null : _handlePrint,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 20),
                      label: Text(
                        _isPrinting ? 'Mencetak...' : 'Cetak Struk',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowMono(
    String left,
    String right, {
    bool isBold = false,
    double fontSize = 12,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
            ),
          ),
          Text(
            right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '--------------------------------',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'monospace',
          color: Colors.grey.shade400,
          letterSpacing: 2,
          fontSize: 10,
        ),
      ),
    );
  }
}
