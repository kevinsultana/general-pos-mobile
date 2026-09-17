import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart';

class PromotionFormDialog extends ConsumerStatefulWidget {
  final Promotion? promotion;

  const PromotionFormDialog({super.key, this.promotion});

  static Future<String?> show(BuildContext context, {Promotion? promotion}) {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => PromotionFormDialog(promotion: promotion),
    );
  }

  @override
  ConsumerState<PromotionFormDialog> createState() =>
      _PromotionFormDialogState();
}

class _PromotionFormDialogState extends ConsumerState<PromotionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _valueController;
  late final TextEditingController _minSpendController;
  late String _discountType;
  late bool _active;
  bool _isLoading = false;

  bool get _isEditing => widget.promotion != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.promotion?.name ?? '');
    _codeController =
        TextEditingController(text: widget.promotion?.code ?? '');
    _valueController = TextEditingController(
      text: widget.promotion != null
          ? widget.promotion!.discountValue.toString()
          : '',
    );
    _minSpendController = TextEditingController(
      text: widget.promotion != null && widget.promotion!.minSpend > 0
          ? widget.promotion!.minSpend.toString()
          : '',
    );
    _discountType = widget.promotion?.discountType == 'FIXED' || widget.promotion?.discountType == 'FIXED_AMOUNT'
        ? 'FIXED_AMOUNT'
        : (widget.promotion?.discountType ?? 'PERCENTAGE');
    _active = widget.promotion?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _valueController.dispose();
    _minSpendController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final val = int.tryParse(_valueController.text.trim()) ?? 0;
    final minSpend = int.tryParse(_minSpendController.text.trim()) ?? 0;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(promotionRepositoryProvider);
      String promoId;

      if (_isEditing) {
        promoId = widget.promotion!.id;
        await repo.updatePromotion(
          id: promoId,
          storeId: widget.promotion!.storeId,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim().toUpperCase()
              : null,
          discountType: _discountType,
          discountValue: val,
          minSpend: minSpend,
          active: _active,
        );
      } else {
        final activeStoreId = ref.read(activeStoreIdProvider);
        promoId = await repo.createPromotion(
          storeId: activeStoreId,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim().toUpperCase()
              : null,
          discountType: _discountType,
          discountValue: val,
          minSpend: minSpend,
          active: _active,
        );
      }

      ref.invalidate(promotionListStreamProvider);

      if (mounted) {
        Navigator.pop(context, promoId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan promo: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManagePromotions =
        ref.watch(hasPermissionProvider(AppPermissions.managePromotions));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEditing ? 'Ubah Promosi / Voucher' : 'Buat Promosi / Voucher Baru',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Promosi *',
                  hintText: 'Contoh: Diskon Gajian 10%',
                  prefixIcon: const Icon(Icons.campaign_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama promosi wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Kode Voucher (Opsional)',
                  hintText: 'Contoh: GAJIAN10',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  helperText: 'Biarkan kosong jika berlaku otomatis',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Discount Type
              const Text(
                'Tipe Diskon',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'PERCENTAGE',
                    label: Text('Persentase (%)'),
                    icon: Icon(Icons.percent_rounded),
                  ),
                  ButtonSegment(
                    value: 'FIXED_AMOUNT',
                    label: Text('Nominal (Rp)'),
                    icon: Icon(Icons.attach_money_rounded),
                  ),
                ],
                selected: {_discountType},
                onSelectionChanged: (set) {
                  setState(() => _discountType = set.first);
                },
              ),
              const SizedBox(height: 16),

              // Discount Value
              TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _discountType == 'PERCENTAGE'
                      ? 'Nilai Diskon (%) *'
                      : 'Nominal Potongan (Rp) *',
                  hintText: _discountType == 'PERCENTAGE' ? '10' : '5000',
                  prefixIcon: Icon(
                    _discountType == 'PERCENTAGE'
                        ? Icons.percent_rounded
                        : Icons.money_rounded,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nilai diskon wajib diisi';
                  }
                  final parsed = int.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Nilai harus lebih besar dari 0';
                  }
                  if (_discountType == 'PERCENTAGE' && parsed > 100) {
                    return 'Diskon persentase maksimal 100%';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Minimum Spend
              TextFormField(
                controller: _minSpendController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Minimal Belanja (Rp)',
                  hintText: 'Contoh: 50000 (0 jika tanpa syarat)',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Active Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Aktif'),
                subtitle: Text(
                  _active
                      ? 'Promosi dapat digunakan oleh kasir/pelanggan'
                      : 'Promosi dinonaktifkan sementara',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _active,
                onChanged: (val) => setState(() => _active = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading || !canManagePromotions ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Simpan' : 'Buat Promo'),
        ),
      ],
    );
  }
}
