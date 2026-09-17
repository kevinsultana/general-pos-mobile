import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../payment/controllers/payment_controller.dart';
import '../../payment/widgets/receipt_dialog.dart';
import '../widgets/refund_dialog.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String _selectedFilter = 'ALL'; // ALL, COMPLETED, CANCELLED, REFUNDED

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionListStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('ALL', 'Semua'),
                _buildFilterChip('COMPLETED', 'Selesai'),
                _buildFilterChip('CANCELLED', 'Dibatalkan'),
                _buildFilterChip('REFUNDED', 'Refund'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transactions List
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                // Filter transactions
                var filtered = transactions.where((t) => t.status != 'DRAFT');

                if (_selectedFilter != 'ALL') {
                  if (_selectedFilter == 'REFUNDED') {
                    filtered = filtered.where(
                      (t) =>
                          t.status == 'REFUNDED' ||
                          t.status == 'PARTIALLY_REFUNDED',
                    );
                  } else {
                    filtered = filtered.where(
                      (t) => t.status == _selectedFilter,
                    );
                  }
                }

                final list = filtered.toList();

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum Ada Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Transaksi kasir yang telah dibayar akan muncul di sini',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final trx = list[index];
                    final dateStr =
                        '${trx.createdAt.day}/${trx.createdAt.month}/${trx.createdAt.year} ${trx.createdAt.hour.toString().padLeft(2, '0')}:${trx.createdAt.minute.toString().padLeft(2, '0')}';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showTransactionDetailModal(trx),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    trx.transactionNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  _buildStatusBadge(trx.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${_formatOrderType(trx.orderType)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  if (trx.queueNumber != null &&
                                      trx.queueNumber!.isNotEmpty)
                                    Text(
                                      ' (${trx.queueNumber})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  if (trx.customerId != null)
                                    FutureBuilder<Customer?>(
                                      future: ref
                                          .read(customerRepositoryProvider)
                                          .getCustomerById(trx.customerId!),
                                      builder: (context, snap) {
                                        if (snap.data == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.person_outline_rounded,
                                                size: 13,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                snap.data!.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Tagihan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Terjadi kesalahan: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimaryLight,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = value;
            });
          }
        },
      ),
    );
  }

  String _formatOrderType(String? type) {
    if (type == null || type.isEmpty) return 'Dine In';
    if (type == 'TAKEAWAY') return 'Takeaway';
    if (type == 'DINE_IN') return 'Dine In';
    if (type == 'DELIVERY') return 'Delivery';
    if (type == 'ONLINE') return 'Online';
    return type;
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'COMPLETED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Selesai';
        break;
      case 'CANCELLED':
        bg = AppColors.danger.withValues(alpha: 0.1);
        fg = AppColors.danger;
        label = 'Dibatalkan';
        break;
      case 'REFUNDED':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        label = 'Refund';
        break;
      case 'PARTIALLY_REFUNDED':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'Partial Refund';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showTransactionDetailModal(Transaction trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TransactionDetailSheet(transaction: trx),
    );
  }
}

class _TransactionDetailSheet extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trxRepo = ref.watch(transactionRepositoryProvider);
    final isCompleted = transaction.status == 'COMPLETED';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.transactionNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      transaction.refundedAt != null
                          ? 'Status: ${transaction.status} • Refund: ${transaction.refundedAt!.day}/${transaction.refundedAt!.month}/${transaction.refundedAt!.year} ${transaction.refundedAt!.hour.toString().padLeft(2, '0')}:${transaction.refundedAt!.minute.toString().padLeft(2, '0')}'
                          : 'Status: ${transaction.status}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items List & Summary
          Expanded(
            child: FutureBuilder<List<TransactionItem>>(
              future: trxRepo.getTransactionItems(transaction.id),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Rincian Item',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.variantNameSnapshot != null
                                        ? '${item.productNameSnapshot} (${item.variantNameSnapshot})'
                                        : item.productNameSnapshot,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}',
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
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 24),

                    // Calculations
                    _buildSummaryRow(
                      'Subtotal',
                      CurrencyFormatter.format(transaction.subtotal),
                    ),
                    if (transaction.discountTotal > 0)
                      _buildSummaryRow(
                        'Diskon Transaksi',
                        '-${CurrencyFormatter.format(transaction.discountTotal)}',
                        color: AppColors.danger,
                      ),
                    if (transaction.roundingAmount != 0)
                      _buildSummaryRow(
                        'Pembulatan Tunai',
                        CurrencyFormatter.formatWithSign(
                          transaction.roundingAmount,
                        ),
                        color: transaction.roundingAmount > 0
                            ? AppColors.warning
                            : AppColors.danger,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL AKHIR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          CurrencyFormatter.format(transaction.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ReceiptDialog.show(
                            context,
                            transactionId: transaction.id,
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('Lihat Struk'),
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple.shade700,
                            side: BorderSide(color: Colors.purple.shade300),
                          ),
                          onPressed: () => _handleRefund(context, ref),
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('Refund'),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        ReceiptDialog.show(
                          context,
                          transactionId: transaction.id,
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text(
                        'Cetak Ulang Struk (Reprint)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () => _handleCancel(context, ref),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Batalkan Transaksi (Void & Reversal)'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _handleCancel(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pembatalan transaksi akan mengembalikan stok produk yang terjual secara otomatis ke inventori (Stock Reversal).',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan *',
                hintText: 'Contoh: Salah input pesanan / Pelanggan batal',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close sheet

              try {
                await ref
                    .read(paymentControllerProvider.notifier)
                    .cancelTransaction(
                      transactionId: transaction.id,
                      reason: reason,
                    );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(
                        'Transaksi berhasil dibatalkan dan stok telah dipulihkan',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text('Gagal membatalkan transaksi: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Konfirmasi Void'),
          ),
        ],
      ),
    );
  }

  void _handleRefund(BuildContext context, WidgetRef ref) async {
    final items = await ref
        .read(transactionRepositoryProvider)
        .getTransactionItems(transaction.id);

    if (!context.mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Tidak ada item transaksi yang dapat di-refund'),
        ),
      );
      return;
    }

    final refunded = await RefundDialog.show(
      context,
      transaction: transaction,
      items: items,
    );

    if (refunded == true && context.mounted) {
      Navigator.pop(context); // Close the detail bottom sheet
    }
  }
}
