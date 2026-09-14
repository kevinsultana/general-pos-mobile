import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart';
import '../controllers/inventory_controller.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final Product product;

  const StockAdjustmentDialog({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();

  bool _isIncrease = false; // Default: Pengurangan (paling umum pada adjustment)
  String _selectedReason = 'Damaged';
  bool _isSubmitting = false;

  final Map<String, String> _reasons = {
    'Damaged': 'Barang Rusak',
    'Lost': 'Barang Hilang',
    'Expired': 'Kadaluarsa',
    'Stock Opname': 'Penyesuaian Fisik (Opname)',
    'Correction': 'Koreksi Kesalahan Input',
  };

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final delta = _isIncrease ? qty : -qty;
    final newStock = widget.product.stock + delta;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Penyesuaian Stok (Adjustment)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Type Selector Segment
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pengurangan (-)')),
                      selected: !_isIncrease,
                      selectedColor: AppColors.danger.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: !_isIncrease ? AppColors.danger : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isIncrease = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Penambahan (+)')),
                      selected: _isIncrease,
                      selectedColor: AppColors.accentContainer,
                      labelStyle: TextStyle(
                        color: _isIncrease ? AppColors.accent : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isIncrease = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity Field
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Kuantitas *',
                  hintText: 'Masukkan jumlah unit',
                  prefixIcon: Icon(Icons.numbers_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Masukkan jumlah minimal 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penyesuaian *',
                  prefixIcon: Icon(Icons.help_outline_rounded),
                ),
                items: _reasons.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedReason = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Summary Preview & Negative Stock Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: newStock < 0
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: newStock < 0 ? AppColors.danger : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Perubahan Stok:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '${widget.product.stock}  ➜  $newStock unit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: newStock < 0 ? AppColors.danger : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    if (newStock < 0) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.danger, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Peringatan: Stok menjadi negatif (diizinkan untuk UMKM).',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isIncrease ? AppColors.accent : AppColors.warning,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (_formKey.currentState?.validate() != true) return;

                            setState(() {
                              _isSubmitting = true;
                            });

                            try {
                              await ref
                                  .read(inventoryControllerProvider.notifier)
                                  .stockAdjustment(
                                    productId: widget.product.id,
                                    deltaQty: delta,
                                    reason: _reasons[_selectedReason] ?? _selectedReason,
                                  );

                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Penyesuaian stok ${widget.product.name} berhasil disimpan',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                });
                              }
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Penyesuaian'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
