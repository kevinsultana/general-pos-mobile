import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/services/cost_calculator.dart';
import '../controllers/inventory_controller.dart';

class StockInDialog extends ConsumerStatefulWidget {
  final Product product;

  const StockInDialog({super.key, required this.product});

  @override
  ConsumerState<StockInDialog> createState() => _StockInDialogState();
}

class _StockInDialogState extends ConsumerState<StockInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _reasonController = TextEditingController(text: 'Pembelian Stok Baru');

  int _addedQty = 0;
  int _newUnitCost = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _newUnitCost = widget.product.cost;
    _costController.text = _newUnitCost.toString();

    _qtyController.addListener(() {
      final parsed = int.tryParse(_qtyController.text) ?? 0;
      if (parsed != _addedQty) {
        setState(() {
          _addedQty = parsed;
        });
      }
    });

    _costController.addListener(() {
      final parsed = int.tryParse(_costController.text) ?? 0;
      if (parsed != _newUnitCost) {
        setState(() {
          _newUnitCost = parsed;
        });
      }
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewNewCost = CostCalculator.calculateWeightedAverageCost(
      existingQty: widget.product.stock,
      existingCost: widget.product.cost,
      addedQty: _addedQty,
      addedCost: _newUnitCost,
    );

    final previewNewStock = widget.product.stock + _addedQty;

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
                          'Stock In (Tambah Stok)',
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

              // Quantity Field
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Jumlah Tambahan Unit *',
                  hintText: 'Contoh: 10',
                  prefixIcon: Icon(Icons.add_box_outlined),
                ),
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Masukkan jumlah unit minimal 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Unit Cost Field
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Harga Beli per Unit Baru (HPP) *',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Masukkan harga beli yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason Field
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Catatan / Alasan (Opsional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Live Weighted Average Cost Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stok:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '${widget.product.stock}  ➜  $previewNewStock unit',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'HPP Rata-Rata Baru:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.format(widget.product.cost)}  ➜  ${CurrencyFormatter.format(previewNewCost)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
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
                                  .stockIn(
                                    productId: widget.product.id,
                                    addedQty: _addedQty,
                                    unitCost: _newUnitCost,
                                    reason: _reasonController.text.trim(),
                                  );

                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Berhasil menambah $_addedQty unit ke ${widget.product.name}',
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
                        : const Text('Simpan Stok Masuk'),
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
