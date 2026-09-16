import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/payment_input.dart';
import '../../../domain/services/cash_rounding_calculator.dart';
import '../../pos/controllers/cart_controller.dart';
import '../controllers/payment_controller.dart';
import 'receipt_dialog.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PaymentSheet(),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  String _selectedMethod = 'CASH'; // CASH, QRIS, TRANSFER, CARD, SPLIT
  late final TextEditingController _cashTenderedController;
  late final TextEditingController _splitCashController;
  late final TextEditingController _cardApprovalController;

  CashRoundingResult? _cashRoundingResult;
  bool _isLoadingRounding = true;

  @override
  void initState() {
    super.initState();
    _cashTenderedController = TextEditingController();
    _splitCashController = TextEditingController();
    _cardApprovalController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCashRounding();
    });
  }

  @override
  void dispose() {
    _cashTenderedController.dispose();
    _splitCashController.dispose();
    _cardApprovalController.dispose();
    super.dispose();
  }

  Future<void> _loadCashRounding() async {
    final cartState = ref.read(cartControllerProvider);
    final result = await ref
        .read(paymentControllerProvider.notifier)
        .calculateCashRounding(cartState.grandTotal);

    if (mounted) {
      setState(() {
        _cashRoundingResult = result;
        _isLoadingRounding = false;
        // Default tendered to exact rounded cash
        _cashTenderedController.text = result.roundedAmount.toString();
      });
    }
  }

  int get _cashTendered =>
      int.tryParse(_cashTenderedController.text.trim()) ?? 0;

  int get _cashChange {
    final due = _cashRoundingResult?.roundedAmount ?? 0;
    return _cashTendered >= due ? _cashTendered - due : 0;
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final paymentState = ref.watch(paymentControllerProvider);
    final isSubmitting = paymentState.isLoading;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payments_rounded,
                        color: AppColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
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

          // Payment Method Selector Tabs
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMethodChip('CASH', 'Tunai', Icons.money_rounded),
                _buildMethodChip(
                    'QRIS', 'QRIS', Icons.qr_code_2_rounded),
                _buildMethodChip(
                    'TRANSFER', 'Transfer', Icons.account_balance_rounded),
                _buildMethodChip(
                    'CARD', 'Kartu / EDC', Icons.credit_card_rounded),
                _buildMethodChip(
                    'SPLIT', 'Split', Icons.call_split_rounded),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Content depending on method
          Expanded(
            child: _isLoadingRounding
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildSelectedMethodBody(cartState.grandTotal),
                  ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting ? null : _handlePaymentSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  isSubmitting ? 'Memproses Transaksi...' : 'Konfirmasi & Selesai',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip(String value, String label, IconData icon) {
    final isSelected = _selectedMethod == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.primary,
        ),
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimaryLight,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedMethod = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildSelectedMethodBody(int rawGrandTotal) {
    switch (_selectedMethod) {
      case 'CASH':
        return _buildCashView(rawGrandTotal);
      case 'QRIS':
        return _buildQrisView(rawGrandTotal);
      case 'TRANSFER':
        return _buildTransferView(rawGrandTotal);
      case 'CARD':
        return _buildCardView(rawGrandTotal);
      case 'SPLIT':
        return _buildSplitView(rawGrandTotal);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCashView(int rawGrandTotal) {
    final rounding = _cashRoundingResult;
    final finalCashDue = rounding?.roundedAmount ?? rawGrandTotal;
    final roundingAmount = rounding?.roundingAmount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breakdown Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tagihan Sebelum Pembulatan',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight)),
                  Text(CurrencyFormatter.format(rawGrandTotal),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              if (roundingAmount != 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pembulatan Tunai (Cash Rounding)',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryLight)),
                    Text(
                      CurrencyFormatter.formatWithSign(roundingAmount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: roundingAmount > 0
                            ? AppColors.warning
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL HARUS DIBAYAR',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CurrencyFormatter.format(finalCashDue),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cash Tendered Input
        const Text(
          'Nominal Uang Diterima (Tendered)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cashTenderedController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            hintText: '0',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Quick Suggestion Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Uang Pas'),
              onPressed: () {
                setState(() {
                  _cashTenderedController.text = finalCashDue.toString();
                });
              },
            ),
            ..._generateQuickCashChips(finalCashDue).map((amount) {
              return ActionChip(
                label: Text(CurrencyFormatter.format(amount)),
                onPressed: () {
                  setState(() {
                    _cashTenderedController.text = amount.toString();
                  });
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 20),

        // Change Return Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cashTendered >= finalCashDue
                ? Colors.green.shade50
                : AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _cashTendered >= finalCashDue
                  ? Colors.green.shade300
                  : AppColors.danger.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cashTendered >= finalCashDue
                    ? 'UANG KEMBALIAN'
                    : 'UANG KURANG (Harap tambah pembayaran)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _cashTendered >= finalCashDue
                      ? Colors.green.shade800
                      : AppColors.danger,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _cashTendered >= finalCashDue
                    ? CurrencyFormatter.format(_cashChange)
                    : '-${CurrencyFormatter.format(finalCashDue - _cashTendered)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _cashTendered >= finalCashDue
                      ? Colors.green.shade800
                      : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrisView(int grandTotal) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              const Text(
                'TOKO BERKAH POS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'NMID: ID1020304050607',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),

              // QR Visual Placeholder
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2_rounded,
                          size: 120, color: Colors.blueGrey.shade800),
                      const Text('SCAN QRIS',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                CurrencyFormatter.format(grandTotal),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pelanggan scan kode QR di atas menggunakan m-banking atau e-wallet (GoPay, OVO, Dana, ShopeePay). Tekan tombol di bawah setelah pembayaran diterima.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferView(int grandTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Transfer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                CurrencyFormatter.format(grandTotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Rekening Bank Tujuan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildBankCard('Bank BCA', '8800-1234-5678', 'Toko Berkah POS'),
        const SizedBox(height: 8),
        _buildBankCard('Bank Mandiri', '137-00-9876543-2', 'Toko Berkah POS'),
      ],
    );
  }

  Widget _buildBankCard(String bank, String accountNo, String name) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bank,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('No. Rek: $accountNo',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('a.n. $name',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView(int grandTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Tagihan Kartu',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                CurrencyFormatter.format(grandTotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Informasi Mesin EDC / Kartu',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cardApprovalController,
          decoration: const InputDecoration(
            labelText: 'Kode Approval / No. Referensi (Opsional)',
            hintText: 'Contoh: APPR-88231',
            prefixIcon: Icon(Icons.numbers_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitView(int grandTotal) {
    final splitCashVal = int.tryParse(_splitCashController.text.trim()) ?? 0;
    final remainingNonCash =
        grandTotal > splitCashVal ? grandTotal - splitCashVal : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Split Payment (Pisah Pembayaran)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bagi pembayaran sebagian menggunakan Tunai dan sisanya Non-Tunai.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Tagihan'),
            Text(
              CurrencyFormatter.format(grandTotal),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _splitCashController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Porsi Tunai (Cash)',
            prefixText: 'Rp ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sisa Bayar (QRIS/Transfer/Kartu):',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                CurrencyFormatter.format(remainingNonCash),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<int> _generateQuickCashChips(int baseAmount) {
    final suggestions = <int>[];
    for (final inc in [10000, 20000, 50000, 100000]) {
      if (inc > baseAmount) {
        suggestions.add(inc);
      }
    }
    // Add next round 10.000 or 50.000 if not included
    final nextRound = ((baseAmount + 9999) ~/ 10000) * 10000;
    if (!suggestions.contains(nextRound) && nextRound > baseAmount) {
      suggestions.add(nextRound);
    }
    suggestions.sort();
    return suggestions.take(3).toList();
  }

  Future<void> _handlePaymentSubmit() async {
    final cartState = ref.read(cartControllerProvider);
    final rawGrandTotal = cartState.grandTotal;

    List<PaymentInput> payments = [];

    if (_selectedMethod == 'CASH') {
      final rounding = _cashRoundingResult;
      final finalCashDue = rounding?.roundedAmount ?? rawGrandTotal;
      final roundingAmount = rounding?.roundingAmount ?? 0;

      if (_cashTendered < finalCashDue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Uang yang diterima kurang dari total tagihan'),
          ),
        );
        return;
      }

      payments.add(PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: rawGrandTotal,
        roundingAmount: roundingAmount,
        tenderedAmount: _cashTendered,
        changeAmount: _cashChange,
      ));
    } else if (_selectedMethod == 'QRIS') {
      payments.add(PaymentInput(
        paymentMethodId: 'pm-qris',
        paymentType: 'QRIS',
        amount: rawGrandTotal,
        roundingAmount: 0,
        referenceNumber: 'QRIS-${DateTime.now().millisecondsSinceEpoch}',
      ));
    } else if (_selectedMethod == 'TRANSFER') {
      payments.add(PaymentInput(
        paymentMethodId: 'pm-transfer',
        paymentType: 'TRANSFER',
        amount: rawGrandTotal,
        roundingAmount: 0,
        referenceNumber: 'TRF-${DateTime.now().millisecondsSinceEpoch}',
      ));
    } else if (_selectedMethod == 'CARD') {
      payments.add(PaymentInput(
        paymentMethodId: 'pm-card',
        paymentType: 'CARD',
        amount: rawGrandTotal,
        roundingAmount: 0,
        referenceNumber: _cardApprovalController.text.trim().isNotEmpty
            ? _cardApprovalController.text.trim()
            : null,
      ));
    } else if (_selectedMethod == 'SPLIT') {
      final cashPart = int.tryParse(_splitCashController.text.trim()) ?? 0;
      final nonCashPart = rawGrandTotal - cashPart;

      if (cashPart <= 0 || nonCashPart <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Harap masukkan pembagian nominal split yang valid'),
          ),
        );
        return;
      }

      // Calculate cash rounding on the cash component
      final cashRounding = await ref
          .read(paymentControllerProvider.notifier)
          .calculateCashRounding(cashPart);

      payments.add(PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: cashPart,
        roundingAmount: cashRounding.roundingAmount,
        tenderedAmount: cashRounding.roundedAmount,
        changeAmount: 0,
      ));

      // Non-cash component strictly pays exact amount with 0 rounding
      payments.add(PaymentInput(
        paymentMethodId: 'pm-qris',
        paymentType: 'QRIS',
        amount: nonCashPart,
        roundingAmount: 0,
      ));
    }

    try {
      final transactionId = await ref
          .read(paymentControllerProvider.notifier)
          .completePayment(payments: payments);

      if (mounted) {
        Navigator.pop(context); // Close PaymentSheet
        ReceiptDialog.show(context, transactionId: transactionId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Gagal menyelesaikan transaksi: $e'),
          ),
        );
      }
    }
  }
}
