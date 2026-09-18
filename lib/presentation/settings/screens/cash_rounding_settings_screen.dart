import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart' show Store;
import '../../../domain/repositories/i_store_repository.dart';
import '../../../domain/services/cash_rounding_calculator.dart';

/// Screen to configure Cash Rounding (Pembulatan Uang Kas / Tunai) for POS checkout.
class CashRoundingSettingsScreen extends ConsumerStatefulWidget {
  const CashRoundingSettingsScreen({super.key});

  @override
  ConsumerState<CashRoundingSettingsScreen> createState() =>
      _CashRoundingSettingsScreenState();
}

class _CashRoundingSettingsScreenState
    extends ConsumerState<CashRoundingSettingsScreen> {
  int _simulatedAmount = 18250;
  static const List<int> _simPresets = [18250, 24600, 51750, 99990];

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(currentStoreStreamProvider);
    final storeRepo = ref.read(storeRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Pembulatan Tunai',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Terjadi kesalahan: $err')),
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Data toko tidak ditemukan'));
          }

          final isEnabled = store.cashRoundingEnabled;
          final increment = store.cashRoundingIncrement;
          final mode = store.cashRoundingMode;

          // Run real-time simulation
          const calculator = CashRoundingCalculator();
          final simResult = calculator.calculate(
            amount: _simulatedAmount,
            mode: CashRoundingMode.fromString(mode),
            increment: increment,
            enabled: isEnabled,
            paymentType: 'CASH',
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // CARD 1: Status Pembulatan Tunai (ON / OFF)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SwitchListTile(
                    key: const Key('cash_rounding_switch'),
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? Colors.amber.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.price_change_rounded,
                        color: isEnabled
                            ? Colors.amber.shade800
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Status Pembulatan Tunai',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isEnabled
                          ? 'Aktif — Total tagihan pembayaran tunai kasir dibulatkan otomatis guna meminimalkan uang receh/koin.'
                          : 'Nonaktif — Pembayaran tunai kasir akan ditagih nominal asli tanpa pembulatan.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: isEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await storeRepo.updateCashRoundingSettings(
                        storeId: store.id,
                        enabled: val,
                        increment: increment,
                        mode: mode,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'Pembulatan Tunai diaktifkan'
                                : 'Pembulatan Tunai dinonaktifkan',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Non-active Alert Banner
              if (!isEnabled) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pembulatan tunai sedang nonaktif. Aktifkan saklar di atas agar kasir menerapkan pembulatan pada transaksi tunai.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // CARD 2: Kelipatan Pembulatan (Increment)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.toll_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Kelipatan Pembulatan (Increment)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih nominal pecahan terkecil untuk meminimalkan kembalian koin:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildIncrementOption(
                        context: context,
                        store: store,
                        storeRepo: storeRepo,
                        value: 100,
                        title: 'Rp 100',
                        desc: 'Standar retail modern (selisih minimal)',
                        isSelected: increment == 100,
                        enabled: isEnabled,
                      ),
                      const SizedBox(height: 8),
                      _buildIncrementOption(
                        context: context,
                        store: store,
                        storeRepo: storeRepo,
                        value: 500,
                        title: 'Rp 500',
                        desc: 'Populer untuk kafe & resto (hindari koin kecil)',
                        isSelected: increment == 500,
                        enabled: isEnabled,
                      ),
                      const SizedBox(height: 8),
                      _buildIncrementOption(
                        context: context,
                        store: store,
                        storeRepo: storeRepo,
                        value: 1000,
                        title: 'Rp 1.000',
                        desc: 'Tanpa koin sama sekali (bulat ke uang kertas)',
                        isSelected: increment == 1000,
                        enabled: isEnabled,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CARD 3: Aturan / Metode Pembulatan (Rounding Mode)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Metode Pembulatan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tentukan rumus saat nilai tagihan berada di antara kelipatan:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildModeOption(
                        context: context,
                        store: store,
                        storeRepo: storeRepo,
                        modeKey: 'ROUND_NEAREST',
                        title: 'Terdekat (Round Nearest)',
                        desc: 'Membulatkan ke kelipatan terdekat (sisa < setengah ke bawah, sisa ≥ setengah ke atas).',
                        icon: Icons.compare_arrows_rounded,
                        isSelected: mode == 'ROUND_NEAREST',
                        enabled: isEnabled,
                      ),
                      const SizedBox(height: 8),
                      _buildModeOption(
                        context: context,
                        store: store,
                        storeRepo: storeRepo,
                        modeKey: 'ROUND_UP',
                        title: 'Selalu Ke Atas (Ceiling)',
                        desc: 'Sisa berapapun selalu dibulatkan ke atas ke kelipatan berikutnya.',
                        icon: Icons.arrow_upward_rounded,
                        isSelected: mode == 'ROUND_UP',
                        enabled: isEnabled,
                      ),
                      const SizedBox(height: 8),
                      _buildModeOption(
                        context: context,
                        store: store,
                        storeRepo: storeRepo,
                        modeKey: 'ROUND_DOWN',
                        title: 'Selalu Ke Bawah (Floor / Diskon)',
                        desc: 'Sisa pecahan selalu dipotong ke bawah (toko memberi potongan receh).',
                        icon: Icons.arrow_downward_rounded,
                        isSelected: mode == 'ROUND_DOWN',
                        enabled: isEnabled,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CARD 4: Live Simulation & Preview Kasir
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isEnabled ? Colors.teal.shade200 : Colors.grey.shade200,
                  ),
                ),
                color: isEnabled ? const Color(0xFFF0FDF4) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            size: 20,
                            color: isEnabled ? Colors.teal.shade800 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simulasi Perhitungan di Kasir',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isEnabled
                                    ? Colors.teal.shade900
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih contoh nominal tagihan untuk menguji simulasi pembulatan:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isEnabled
                              ? Colors.teal.shade900.withValues(alpha: 0.75)
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Preset Amount Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _simPresets.map((amt) {
                          final isSelected = _simulatedAmount == amt;
                          return ChoiceChip(
                            label: Text(CurrencyFormatter.format(amt)),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _simulatedAmount = amt);
                            },
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Simulation Result Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isEnabled
                                ? Colors.teal.shade200
                                : Colors.grey.shade300,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _simRow(
                              'Total Tagihan Belanja',
                              CurrencyFormatter.format(simResult.originalAmount),
                              isBold: false,
                              textColor: AppColors.textPrimaryLight,
                            ),
                            const SizedBox(height: 6),
                            _simRow(
                              'Penyesuaian Pembulatan',
                              isEnabled
                                  ? CurrencyFormatter.formatWithSign(
                                      simResult.roundingAmount,
                                    )
                                  : 'Rp 0 (Nonaktif)',
                              isBold: true,
                              textColor: !isEnabled
                                  ? Colors.grey.shade600
                                  : simResult.roundingAmount > 0
                                      ? Colors.blue.shade700
                                      : simResult.roundingAmount < 0
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                              badge: isEnabled && simResult.roundingAmount != 0
                                  ? (simResult.roundingAmount > 0
                                      ? 'Pembulatan Ke Atas'
                                      : 'Diskon Pembulatan')
                                  : null,
                            ),
                            const Divider(height: 18),
                            _simRow(
                              'TOTAL BAYAR TUNAI',
                              CurrencyFormatter.format(simResult.roundedAmount),
                              isBold: true,
                              fontSize: 15,
                              textColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Thermal receipt reminder note
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 15,
                            color: isEnabled
                                ? Colors.teal.shade800
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pada struk pembayaran tunai, penyesuaian pembulatan akan dicetak jelas sehingga pelanggan memahami rincian kembalian.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isEnabled
                                    ? Colors.teal.shade900
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIncrementOption({
    required BuildContext context,
    required Store store,
    required IStoreRepository storeRepo,
    required int value,
    required String title,
    required String desc,
    required bool isSelected,
    required bool enabled,
  }) {
    return InkWell(
      key: Key('increment_$value'),
      onTap: enabled
          ? () {
              storeRepo.updateCashRoundingSettings(
                storeId: store.id,
                enabled: true,
                increment: value,
                mode: store.cashRoundingMode,
              );
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required Store store,
    required IStoreRepository storeRepo,
    required String modeKey,
    required String title,
    required String desc,
    required IconData icon,
    required bool isSelected,
    required bool enabled,
  }) {
    return InkWell(
      key: Key('mode_$modeKey'),
      onTap: enabled
          ? () {
              storeRepo.updateCashRoundingSettings(
                storeId: store.id,
                enabled: true,
                increment: store.cashRoundingIncrement,
                mode: modeKey,
              );
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.primary : Colors.grey.shade400,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 15, color: isSelected ? AppColors.primary : Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simRow(
    String label,
    String value, {
    required bool isBold,
    required Color textColor,
    double fontSize = 13,
    String? badge,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold
                    ? AppColors.textPrimaryLight
                    : AppColors.textSecondaryLight,
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
