import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/services/transaction_calculator.dart';

class DiscountDialog extends StatefulWidget {
  final String title;
  final int baseAmount;
  final String? initialType; // 'PERCENTAGE' or 'FIXED'
  final int? initialValue;
  final void Function(String? type, int? value) onApply;

  const DiscountDialog({
    super.key,
    required this.title,
    required this.baseAmount,
    this.initialType,
    this.initialValue,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required int baseAmount,
    String? initialType,
    int? initialValue,
    required void Function(String? type, int? value) onApply,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DiscountDialog(
        title: title,
        baseAmount: baseAmount,
        initialType: initialType,
        initialValue: initialValue,
        onApply: onApply,
      ),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late String _discountType;
  late final TextEditingController _valueController;
  final _calculator = const TransactionCalculator();

  @override
  void initState() {
    super.initState();
    _discountType = widget.initialType ?? 'PERCENTAGE';
    _valueController = TextEditingController(
      text: widget.initialValue != null && widget.initialValue! > 0
          ? widget.initialValue.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  int get _parsedValue => int.tryParse(_valueController.text.trim()) ?? 0;

  int get _calculatedDiscount => _calculator.calculateDiscount(
        subtotal: widget.baseAmount,
        discountType: _discountType,
        discountValue: _parsedValue,
      );

  int get _finalAmount => widget.baseAmount - _calculatedDiscount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Base amount info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jumlah Dasar:',
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
                Text(
                  CurrencyFormatter.format(widget.baseAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'PERCENTAGE',
                  label: Text('Persen (%)'),
                  icon: Icon(Icons.percent_rounded),
                ),
                ButtonSegment(
                  value: 'FIXED',
                  label: Text('Nominal (Rp)'),
                  icon: Icon(Icons.money_rounded),
                ),
              ],
              selected: {_discountType},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _discountType = newSelection.first;
                  _valueController.clear();
                });
              },
            ),
            const SizedBox(height: 16),

            // Value Input Field
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: InputDecoration(
                labelText: _discountType == 'PERCENTAGE'
                    ? 'Persentase Diskon (0 - 100%)'
                    : 'Nominal Diskon (Rp)',
                prefixText: _discountType == 'FIXED' ? 'Rp ' : null,
                suffixText: _discountType == 'PERCENTAGE' ? '%' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Preview calculation box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Potongan Diskon:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                      Text(
                        CurrencyFormatter.format(_calculatedDiscount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Setelah Diskon:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        CurrencyFormatter.format(_finalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initialValue != null && widget.initialValue! > 0)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              widget.onApply(null, null);
              Navigator.pop(context);
            },
            child: const Text('Hapus Diskon'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            final val = _parsedValue;
            if (val <= 0) {
              widget.onApply(null, null);
            } else {
              widget.onApply(_discountType, val);
            }
            Navigator.pop(context);
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}
