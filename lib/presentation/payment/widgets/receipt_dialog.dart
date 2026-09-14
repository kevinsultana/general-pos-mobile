import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/models/receipt_data.dart';
import '../../../domain/repositories/i_transaction_repository.dart';
import '../../common/widgets/receipt_preview_dialog.dart';

class ReceiptDialog extends ConsumerStatefulWidget {
  final String transactionId;

  const ReceiptDialog({super.key, required this.transactionId});

  static Future<void> show(BuildContext context, {required String transactionId}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReceiptDialog(transactionId: transactionId),
    );
  }

  @override
  ConsumerState<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<ReceiptDialog> {
  bool _isPrinting = false;
  bool _autoPrintTriggered = false;

  ReceiptData _buildReceiptData({
    required Transaction trx,
    required List<TransactionItem> items,
    required List<Payment> payments,
    Store? store,
    Customer? customer,
  }) {
    return ReceiptData(
      transactionId: trx.id,
      invoiceNumber: trx.transactionNumber,
      transactionDate: trx.completedAt ?? trx.createdAt,
      cashierName: 'Kasir',
      customerName: customer?.name,
      storeHeader: ReceiptHeader(
        storeName: store?.name ?? 'TOKO UMKM POS',
        storeAddress: store?.address,
        storePhone: store?.phone,
        headerMessage: 'Struk Resmi Pembelian',
      ),
      items: items.map((it) {
        return ReceiptItem(
          productName: it.productNameSnapshot,
          variantName: it.variantNameSnapshot,
          quantity: it.quantity / 1000.0,
          unitPrice: it.unitPrice,
          subtotal: it.subtotal,
          discountAmount: it.discountAmount,
          finalPrice: it.total,
          note: null,
        );
      }).toList(),
      subtotal: trx.subtotal,
      orderDiscount: trx.discountTotal,
      cashRounding: trx.roundingAmount,
      grandTotal: trx.total,
      payments: payments.map((p) {
        return ReceiptPayment(
          method: _formatPaymentMethod(p.paymentMethodId),
          amount: p.amount,
        );
      }).toList(),
      amountPaid: payments.fold<int>(0, (sum, p) {
        if (p.metadata != null) {
          try {
            final meta = jsonDecode(p.metadata!) as Map<String, dynamic>;
            if (meta['tenderedAmount'] != null) {
              return sum + (meta['tenderedAmount'] as num).toInt();
            }
          } catch (_) {}
        }
        return sum + p.amount;
      }),
      changeAmount: payments.fold<int>(0, (sum, p) {
        if (p.metadata != null) {
          try {
            final meta = jsonDecode(p.metadata!) as Map<String, dynamic>;
            if (meta['changeAmount'] != null) {
              return sum + (meta['changeAmount'] as num).toInt();
            }
          } catch (_) {}
        }
        return sum;
      }),
      footerMessage: 'Terima kasih atas kunjungan Anda!',
    );
  }

  KitchenTicketData _buildKitchenTicketData({
    required Transaction trx,
    required List<TransactionItem> items,
    Customer? customer,
  }) {
    return KitchenTicketData(
      orderId: trx.id,
      invoiceNumber: trx.transactionNumber,
      orderTime: trx.completedAt ?? trx.createdAt,
      tableOrCustomer: trx.queueNumber != null && trx.queueNumber!.isNotEmpty
          ? 'Antrian #${trx.queueNumber}'
          : (customer?.name ?? (trx.orderType == 'TAKEAWAY' ? 'Takeaway' : 'Dine In')),
      cashierName: 'Kasir',
      items: items.map((it) {
        return ReceiptItem(
          productName: it.productNameSnapshot,
          variantName: it.variantNameSnapshot,
          quantity: it.quantity / 1000.0,
          unitPrice: it.unitPrice,
          subtotal: it.subtotal,
          discountAmount: it.discountAmount,
          finalPrice: it.total,
          note: null,
        );
      }).toList(),
    );
  }

  Future<void> _handleDirectPrint(ReceiptData receiptData) async {
    setState(() => _isPrinting = true);
    final printerService = ref.read(printerServiceProvider);

    try {
      final success = await printerService.printReceipt(receiptData);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Struk berhasil dicetak ke printer thermal'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tidak dapat mencetak: Printer thermal tidak terhubung. Periksa Bluetooth atau gunakan "Pratinjau Struk".',
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

  Future<void> _handleKitchenPrint(KitchenTicketData ticketData) async {
    setState(() => _isPrinting = true);
    final printerService = ref.read(printerServiceProvider);

    try {
      final success = await printerService.printKitchenTicket(ticketData);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tiket dapur berhasil dicetak'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tidak dapat mencetak tiket dapur: Printer tidak terhubung.',
              ),
              backgroundColor: AppColors.danger,
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
    final trxRepo = ref.watch(transactionRepositoryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadReceiptData(trxRepo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat Struk Transaksi...'),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 48),
                  const SizedBox(height: 12),
                  Text('Gagal memuat struk: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            );
          }

          final trx = snapshot.data!['transaction'] as Transaction;
          final items = snapshot.data!['items'] as List<TransactionItem>;
          final payments = snapshot.data!['payments'] as List<Payment>;
          final store = snapshot.data!['store'] as Store?;
          final customer = snapshot.data!['customer'] as Customer?;

          final receiptData = _buildReceiptData(
            trx: trx,
            items: items,
            payments: payments,
            store: store,
            customer: customer,
          );

          final kitchenTicketData = _buildKitchenTicketData(
            trx: trx,
            items: items,
            customer: customer,
          );

          // Trigger Auto Print once if configured
          if (!_autoPrintTriggered) {
            _autoPrintTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(printerServiceProvider)
                  .handleAutoPrintOnTransactionCompleted(
                    receiptData,
                    kitchenTicket: kitchenTicketData,
                  );
            });
          }

          final dateStr =
              '${trx.completedAt?.day ?? trx.createdAt.day}/${trx.completedAt?.month ?? trx.createdAt.month}/${trx.completedAt?.year ?? trx.createdAt.year} ${trx.completedAt?.hour.toString().padLeft(2, '0') ?? trx.createdAt.hour.toString().padLeft(2, '0')}:${trx.completedAt?.minute.toString().padLeft(2, '0') ?? trx.createdAt.minute.toString().padLeft(2, '0')}';

          return Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: Colors.green.shade700, size: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'PEMBAYARAN BERHASIL',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receipt Container (Paper styling)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Store Info
                        Center(
                          child: Text(
                            store?.name.toUpperCase() ?? 'UMKM POS INDONESIA',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Struk Resmi Pembelian',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Transaction meta
                        _buildRow('No. Transaksi', trx.transactionNumber),
                        _buildRow('Waktu', dateStr),
                        _buildRow(
                          'Tipe Pesanan',
                          trx.orderType == 'TAKEAWAY' ? 'Takeaway' : 'Dine In',
                        ),
                        if (trx.queueNumber != null &&
                            trx.queueNumber!.isNotEmpty)
                          _buildRow('No. Antrian', trx.queueNumber!),
                        if (customer != null)
                          _buildRow('Pelanggan', customer.name),

                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Items
                        ...items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productNameSnapshot,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (item.variantNameSnapshot != null)
                                        Text(
                                          item.variantNameSnapshot!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      Text(
                                        '${(item.quantity / 1000).toStringAsFixed(item.quantity % 1000 == 0 ? 0 : 2)} x ${CurrencyFormatter.format(item.unitPrice)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.total),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Totals
                        _buildRow(
                          'Subtotal',
                          CurrencyFormatter.format(trx.subtotal),
                        ),
                        if (trx.discountTotal > 0)
                          _buildRow(
                            'Diskon Transaksi',
                            '-${CurrencyFormatter.format(trx.discountTotal)}',
                            valueColor: Colors.red.shade700,
                          ),
                        if (trx.roundingAmount != 0)
                          _buildRow(
                            'Pembulatan Tunai',
                            '${trx.roundingAmount > 0 ? '+' : ''}${CurrencyFormatter.format(trx.roundingAmount)}',
                          ),

                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(trx.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Payment Methods
                        ...payments.map((p) {
                          return _buildRow(
                            'Metode Pembayaran',
                            '${_formatPaymentMethod(p.paymentMethodId)}: ${CurrencyFormatter.format(p.amount)}',
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // PRINTER ACTIONS (Phase 7)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isPrinting
                          ? null
                          : () => _handleDirectPrint(receiptData),
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
                        _isPrinting ? 'Mencetak...' : 'Cetak Struk Thermal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ReceiptPreviewDialog.show(context, receiptData);
                          },
                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                          label: const Text('Pratinjau Struk',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleKitchenPrint(kitchenTicketData),
                          icon: const Icon(Icons.restaurant_rounded, size: 16),
                          label: const Text('Tiket Dapur',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Close / New Transaction Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tutup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded,
                              size: 18),
                          label: const Text('Transaksi Baru'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaymentMethod(String methodId) {
    if (methodId.contains('cash')) return 'Tunai';
    if (methodId.contains('qris')) return 'QRIS';
    if (methodId.contains('transfer')) return 'Transfer';
    if (methodId.contains('card')) return 'Kartu Debit/Kredit';
    return 'Lainnya';
  }

  Future<Map<String, dynamic>> _loadReceiptData(
      ITransactionRepository repo) async {
    final transaction = await repo.getTransaction(widget.transactionId);
    final items = await repo.getTransactionItems(widget.transactionId);
    final payments = await repo.getTransactionPayments(widget.transactionId);

    final storeRepo = ref.read(storeRepositoryProvider);
    final store = await storeRepo.getStore(AppConstants.defaultStoreId);

    Customer? customer;
    if (transaction != null && transaction.customerId != null) {
      final customerRepo = ref.read(customerRepositoryProvider);
      customer = await customerRepo.getCustomerById(transaction.customerId!);
    }

    return {
      'transaction': transaction,
      'items': items,
      'payments': payments,
      'store': store,
      'customer': customer,
    };
  }
}
