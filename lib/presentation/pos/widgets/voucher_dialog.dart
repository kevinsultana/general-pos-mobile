import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/models/cart_item.dart';
import '../../../domain/services/promotion_validator.dart';
import '../../../domain/services/transaction_calculator.dart';

class VoucherDialog extends ConsumerStatefulWidget {
  final int baseAmount;
  final List<CartItem> cartItems;
  final String? currentVoucherCode;
  final String? currentPromotionId;
  final String? initialType;
  final int? initialValue;

  const VoucherDialog({
    super.key,
    required this.baseAmount,
    required this.cartItems,
    this.currentVoucherCode,
    this.currentPromotionId,
    this.initialType,
    this.initialValue,
  });

  static Future<void> show(
    BuildContext context, {
    required int baseAmount,
    required List<CartItem> cartItems,
    String? currentVoucherCode,
    String? currentPromotionId,
    String? initialType,
    int? initialValue,
    required void Function({
      required String? discountType,
      required int? discountValue,
      String? promotionId,
      String? voucherCode,
    }) onApply,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => VoucherDialog(
        baseAmount: baseAmount,
        cartItems: cartItems,
        currentVoucherCode: currentVoucherCode,
        currentPromotionId: currentPromotionId,
        initialType: initialType,
        initialValue: initialValue,
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        onApply(
          discountType: result['discountType'] as String?,
          discountValue: result['discountValue'] as int?,
          promotionId: result['promotionId'] as String?,
          voucherCode: result['voucherCode'] as String?,
        );
      }
    });
  }

  @override
  ConsumerState<VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends ConsumerState<VoucherDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual tab state
  late String _manualType;
  late final TextEditingController _manualValueController;
  final _calculator = const TransactionCalculator();

  // Voucher tab state
  final _voucherCodeController = TextEditingController();
  PromotionValidationResult? _voucherValidation;
  Promotion? _validatedPromo;
  String? _voucherError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.currentPromotionId != null ? 1 : 0,
    );
    _manualType = widget.initialType == 'FIXED' || widget.initialType == 'FIXED_AMOUNT'
        ? 'FIXED_AMOUNT'
        : (widget.initialType ?? 'PERCENTAGE');
    _manualValueController = TextEditingController(
      text: widget.initialValue != null && widget.initialValue! > 0
          ? widget.initialValue.toString()
          : '',
    );
    if (widget.currentVoucherCode != null) {
      _voucherCodeController.text = widget.currentVoucherCode!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualValueController.dispose();
    _voucherCodeController.dispose();
    super.dispose();
  }

  int get _parsedManualValue =>
      int.tryParse(_manualValueController.text.trim()) ?? 0;

  int get _calculatedManualDiscount => _calculator.calculateDiscount(
        subtotal: widget.baseAmount,
        discountType: _manualType,
        discountValue: _parsedManualValue,
      );

  Future<void> _checkVoucherCode(String code) async {
    if (code.trim().isEmpty) return;

    setState(() {
      _voucherError = null;
      _voucherValidation = null;
      _validatedPromo = null;
    });

    final promoRepo = ref.read(promotionRepositoryProvider);
    final activeStoreId = ref.read(activeStoreIdProvider);
    final promo = await promoRepo.getPromotionByCode(
      activeStoreId,
      code.trim().toUpperCase(),
    );

    if (promo == null) {
      setState(() {
        _voucherError = 'Kode voucher "$code" tidak ditemukan';
      });
      return;
    }

    final validator = ref.read(promotionValidatorProvider);
    final result = validator.validate(
      active: promo.active,
      startDate: promo.startDate,
      endDate: promo.endDate,
      minSpend: promo.minSpend,
      productId: promo.productId,
      discountType: promo.discountType,
      discountValue: promo.discountValue,
      cartSubtotal: widget.baseAmount,
      cartItems: widget.cartItems,
    );

    setState(() {
      _validatedPromo = promo;
      _voucherValidation = result;
      if (!result.isValid) {
        _voucherError = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final promotionsAsync = ref.watch(promotionListStreamProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Diskon & Voucher',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Diskon Manual'),
              Tab(text: 'Voucher & Promo'),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        height: 380,
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Manual Discount
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Belanja:',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                      Text(
                        CurrencyFormatter.format(widget.baseAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'PERCENTAGE',
                        label: Text('Persen (%)'),
                        icon: Icon(Icons.percent_rounded),
                      ),
                      ButtonSegment(
                        value: 'FIXED_AMOUNT',
                        label: Text('Nominal (Rp)'),
                        icon: Icon(Icons.money_rounded),
                      ),
                    ],
                    selected: {_manualType},
                    onSelectionChanged: (set) {
                      setState(() {
                        _manualType = set.first;
                        _manualValueController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualValueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _manualType == 'PERCENTAGE'
                          ? 'Persentase Diskon (0 - 100%)'
                          : 'Nominal Potongan (Rp)',
                      prefixText: _manualType == 'PERCENTAGE' ? null : 'Rp ',
                      suffixText: _manualType == 'PERCENTAGE' ? '%' : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Potongan Diskon:'),
                        Text(
                          CurrencyFormatter.format(_calculatedManualDiscount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (widget.initialValue != null &&
                          widget.initialValue! > 0)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            onPressed: () {
                              Navigator.pop(context, {
                                'discountType': null,
                                'discountValue': null,
                                'promotionId': null,
                                'voucherCode': null,
                              });
                            },
                            child: const Text('Hapus Diskon'),
                          ),
                        ),
                      if (widget.initialValue != null &&
                          widget.initialValue! > 0)
                        const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context, {
                              'discountType': _manualType,
                              'discountValue': _parsedManualValue,
                              'promotionId': null,
                              'voucherCode': null,
                            });
                          },
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // TAB 2: Voucher Code & Active Promotions
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Voucher input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _voucherCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Kode Voucher',
                            hintText: 'Misal: DISKON10',
                            prefixIcon: const Icon(
                              Icons.confirmation_number_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () =>
                            _checkVoucherCode(_voucherCodeController.text),
                        child: const Text('Cek'),
                      ),
                    ],
                  ),

                  if (_voucherError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _voucherError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  if (_voucherValidation != null &&
                      _voucherValidation!.isValid &&
                      _validatedPromo != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.green.shade700, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _validatedPromo!.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                                Text(
                                  'Hemat ${CurrencyFormatter.format(_voucherValidation!.discountAmount)}',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.pop(context, {
                                'discountType': _validatedPromo!.discountType,
                                'discountValue': _validatedPromo!.discountValue,
                                'promotionId': _validatedPromo!.id,
                                'voucherCode': _validatedPromo!.code,
                              });
                            },
                            child: const Text('Gunakan'),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text(
                    'Promosi Toko Tersedia:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),

                  promotionsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error: $err'),
                    data: (promos) {
                      final activePromos =
                          promos.where((p) => p.active).toList();
                      if (activePromos.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Tidak ada promosi toko aktif saat ini.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        );
                      }

                      final validator =
                          ref.read(promotionValidatorProvider);

                      return Column(
                        children: activePromos.map((p) {
                          final res = validator.validate(
                            active: p.active,
                            startDate: p.startDate,
                            endDate: p.endDate,
                            minSpend: p.minSpend,
                            productId: p.productId,
                            discountType: p.discountType,
                            discountValue: p.discountValue,
                            cartSubtotal: widget.baseAmount,
                            cartItems: widget.cartItems,
                          );

                          final isApplied =
                              p.id == widget.currentPromotionId;

                          return Card(
                            elevation: 0.5,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isApplied
                                    ? AppColors.primary
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                p.discountType == 'PERCENTAGE'
                                    ? 'Diskon ${p.discountValue}% (Min. ${CurrencyFormatter.format(p.minSpend)})'
                                    : 'Diskon ${CurrencyFormatter.format(p.discountValue)} (Min. ${CurrencyFormatter.format(p.minSpend)})',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: isApplied
                                  ? const Text(
                                      'Dipakai',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : res.isValid
                                      ? ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context, {
                                              'discountType': p.discountType,
                                              'discountValue': p.discountValue,
                                              'promotionId': p.id,
                                              'voucherCode': p.code,
                                            });
                                          },
                                          child: const Text('Pilih'),
                                        )
                                      : Text(
                                          'Syarat belum cukup',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 10,
                                          ),
                                        ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
