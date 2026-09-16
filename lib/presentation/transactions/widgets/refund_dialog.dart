import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/models/payment_input.dart';
import '../../payment/controllers/payment_controller.dart';

class RefundDialog extends ConsumerStatefulWidget {
  final Transaction transaction;
  final List<TransactionItem> items;

  const RefundDialog({
    super.key,
    required this.transaction,
    required this.items,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Transaction transaction,
    required List<TransactionItem> items,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RefundDialog(
        transaction: transaction,
        items: items,
      ),
    );
  }

  @override
  ConsumerState<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends ConsumerState<RefundDialog> {
  bool _isFullRefund = true;
  late Map<String, int> _refundQuantities;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _refundQuantities = {
      for (final item in widget.items) item.id: item.quantity.round(),
    };
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _totalRefundQty {
    return _refundQuantities.values.fold(0, (sum, q) => sum + q);
  }

  int get _totalRefundAmount {
    int total = 0;
    for (final item in widget.items) {
      final qty = _refundQuantities[item.id] ?? 0;
      total += qty * item.unitPrice;
    }
    return total;
  }

  bool get _isEffectivelyFull {
    final originalTotalQty =
        widget.items.fold<int>(0, (sum, i) => sum + i.quantity.round());
    return _totalRefundQty >= originalTotalQty;
  }

  void _onToggleMode(bool full) {
    setState(() {
      _isFullRefund = full;
      if (full) {
        // Reset all to max quantity
        _refundQuantities = {
          for (final item in widget.items) item.id: item.quantity.round(),
        };
      }
    });
  }

  void _changeItemQty(String itemId, int delta, int maxQty) {
    setState(() {
      final current = _refundQuantities[itemId] ?? 0;
      final updated = (current + delta).clamp(0, maxQty);
      _refundQuantities[itemId] = updated;

      // Update toggle state based on quantities
      _isFullRefund = _isEffectivelyFull;
    });
  }

  Future<void> _submitRefund() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Alasan refund wajib diisi'),
        ),
      );
      return;
    }

    if (_totalRefundQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Pilih minimal 1 barang untuk di-refund'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final refundItems = widget.items
          .where((item) => (_refundQuantities[item.id] ?? 0) > 0)
          .map((item) {
        final qty = _refundQuantities[item.id]!;
        return RefundItemInput(
          transactionItemId: item.id,
          productId: item.productId,
          variantId: item.variantId,
          quantity: qty,
          refundAmount: qty * item.unitPrice,
        );
      }).toList();

      await ref.read(paymentControllerProvider.notifier).refundTransaction(
            transactionId: widget.transaction.id,
            reason: reason,
            items: refundItems,
            totalRefundAmount: _totalRefundAmount,
          );

      if (mounted) {
        Navigator.pop(context, true);
        final isFull = _isEffectivelyFull;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              isFull
                  ? 'Refund Penuh berhasil diproses (${CurrencyFormatter.format(_totalRefundAmount)}). Stok telah dipulihkan.'
                  : 'Refund Sebagian ($_totalRefundQty unit / ${CurrencyFormatter.format(_totalRefundAmount)}) berhasil diproses. Stok telah dipulihkan.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Gagal memproses refund: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.assignment_return_rounded, color: Colors.purple.shade700, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proses Refund Transaksi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.transaction.transactionNumber,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode Switcher (Full vs Partial)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onToggleMode(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isFullRefund ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isFullRefund
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Refund Penuh',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _isFullRefund ? FontWeight.bold : FontWeight.normal,
                              color: _isFullRefund ? Colors.purple.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onToggleMode(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isFullRefund ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isFullRefund
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Refund Sebagian',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_isFullRefund ? FontWeight.bold : FontWeight.normal,
                              color: !_isFullRefund ? Colors.purple.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Items Selection List
              Text(
                _isFullRefund ? 'Daftar Barang (Semua Dikembalikan)' : 'Pilih Barang & Jumlah Refund',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (ctx, idx) {
                    final item = widget.items[idx];
                    final currentRefundQty = _refundQuantities[item.id] ?? 0;
                    final isSelected = currentRefundQty > 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productNameSnapshot,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? Colors.black87 : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${CurrencyFormatter.format(item.unitPrice)} x $currentRefundQty unit = ${CurrencyFormatter.format(currentRefundQty * item.unitPrice)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.purple.shade700 : Colors.grey.shade500,
                                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Quantity Stepper (if partial)
                          if (!_isFullRefund)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  color: currentRefundQty > 0 ? Colors.purple.shade700 : Colors.grey.shade300,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: currentRefundQty > 0
                                      ? () => _changeItemQty(item.id, -1, item.quantity.round())
                                      : null,
                                ),
                                Container(
                                  width: 28,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$currentRefundQty',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  color: currentRefundQty < item.quantity ? Colors.purple.shade700 : Colors.grey.shade300,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: currentRefundQty < item.quantity.round()
                                      ? () => _changeItemQty(item.id, 1, item.quantity.round())
                                      : null,
                                ),
                              ],
                            )
                          else
                            Text(
                              '${item.quantity} unit',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Total Refund Calculation Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Dana Dikembalikan:',
                          style: TextStyle(fontSize: 11, color: Colors.purple),
                        ),
                        Text(
                          CurrencyFormatter.format(_totalRefundAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isEffectivelyFull ? Colors.purple.shade700 : Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isEffectivelyFull ? 'FULL REFUND' : 'PARTIAL REFUND',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Mandatory Reason field
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Alasan Refund *',
                  hintText: 'Contoh: Barang cacat / basi / salah pesan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: (_isSubmitting || _totalRefundQty <= 0) ? null : _submitRefund,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Proses Refund (${CurrencyFormatter.format(_totalRefundAmount)})'),
        ),
      ],
    );
  }
}
