import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/thousands_separator_input_formatter.dart';
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

  List<ProductVariant> _variants = [];
  ProductVariant? _selectedVariant;

  int _addedQty = 0;
  int _newUnitCost = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _newUnitCost = widget.product.cost;
    _costController.text = ThousandsSeparatorInputFormatter.format(_newUnitCost);
    _loadVariants();

    _qtyController.addListener(() {
      final parsed = ThousandsSeparatorInputFormatter.parse(_qtyController.text);
      if (parsed != _addedQty) {
        setState(() {
          _addedQty = parsed;
        });
      }
    });

    _costController.addListener(() {
      final parsed = ThousandsSeparatorInputFormatter.parse(_costController.text);
      if (parsed != _newUnitCost) {
        setState(() {
          _newUnitCost = parsed;
        });
      }
    });
  }

  Future<void> _loadVariants() async {
    final variants = await ref
        .read(productRepositoryProvider)
        .getVariants(widget.product.id);
    if (mounted && variants.isNotEmpty) {
      setState(() {
        _variants = variants;
        _selectedVariant = variants.first;
        _newUnitCost = _selectedVariant!.cost;
        _costController.text = ThousandsSeparatorInputFormatter.format(_newUnitCost);
      });
    }
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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

              // Variant Selector (if product has variants)
              if (_variants.isNotEmpty) ...[
                DropdownButtonFormField<ProductVariant>(
                  initialValue: _selectedVariant,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Varian *',
                    prefixIcon: Icon(Icons.style_rounded),
                  ),
                  items: _variants
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                              '${v.name} (Stok saat ini: ${ThousandsSeparatorInputFormatter.format(v.stock)})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedVariant = val;
                        _newUnitCost = val.cost;
                        _costController.text =
                            ThousandsSeparatorInputFormatter.format(_newUnitCost);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Quantity Field
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Jumlah Tambahan Unit *',
                  hintText: 'Contoh: 10',
                  prefixIcon: Icon(Icons.add_box_outlined),
                ),
                validator: (val) {
                  final parsed = ThousandsSeparatorInputFormatter.parse(val);
                  if (parsed <= 0) {
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
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Harga Beli per Unit Baru (HPP) *',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
                validator: (val) {
                  final parsed = ThousandsSeparatorInputFormatter.parse(val);
                  if (parsed < 0) {
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
                    if (_selectedVariant != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Stok Varian ${_selectedVariant!.name}:',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${ThousandsSeparatorInputFormatter.format(_selectedVariant!.stock)} ➜ ${ThousandsSeparatorInputFormatter.format(_selectedVariant!.stock + _addedQty)} unit',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Text(
                          _selectedVariant != null ? 'Total Stok Master:' : 'Estimasi Stok:',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${ThousandsSeparatorInputFormatter.format(widget.product.stock)} ➜ ${ThousandsSeparatorInputFormatter.format(previewNewStock)} unit',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HPP Saat Ini',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(widget.product.cost),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'HPP Rata-Rata Baru',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyFormatter.format(previewNewCost),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
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
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
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
                                    variantId: _selectedVariant?.id,
                                    addedQty: _addedQty,
                                    unitCost: _newUnitCost,
                                    reason: _reasonController.text.trim(),
                                  );

                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Berhasil menambah ${ThousandsSeparatorInputFormatter.format(_addedQty)} unit ke ${widget.product.name}',
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
                        : const Text(
                            'Simpan Stok Masuk',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
