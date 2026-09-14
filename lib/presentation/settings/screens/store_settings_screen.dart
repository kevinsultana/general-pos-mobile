import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../core/theme/app_colors.dart';

class StoreSettingsScreen extends ConsumerWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(currentStoreStreamProvider);
    final modeAsync = ref.watch(appOperationalModeProvider);
    final isCloud = modeAsync.valueOrNull == AppOperationalMode.cloud;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan Toko',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (store) {
          if (store == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.storefront_outlined,
                        size: 64, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Menyiapkan Pengaturan Toko...',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => ref
                          .read(storeRepositoryProvider)
                          .ensureDefaultStore(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Inisialisasi Toko'),
                    ),
                  ],
                ),
              ),
            );
          }

          final storeRepo = ref.read(storeRepositoryProvider);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Store Profile Card
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.store_rounded,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mata Uang: ${store.currency} | Mode: Local First',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: Feature Toggles (PRD 41)
              const Text(
                'FITUR POS & TRANSAKSI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Customer Module Toggle
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.people_alt_rounded,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      title: const Text(
                        'Modul Pelanggan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Aktifkan untuk menyimpan data pelanggan dan menetapkan pelanggan pada transaksi kasir POS.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: store.customerEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) async {
                        final messenger = ScaffoldMessenger.of(context);
                        await storeRepo.setCustomerEnabled(store.id, val);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(val
                                ? 'Modul Pelanggan diaktifkan'
                                : 'Modul Pelanggan dinonaktifkan'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: Cash Rounding Settings (PRD 21)
              const Text(
                'PEMBULATAN UANG KAS (CASH ROUNDING)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),

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
                      // Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Aktifkan Pembulatan Tunai',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Hanya berlaku untuk pembayaran kas/tunai guna menghindari receh.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: store.cashRoundingEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          storeRepo.updateCashRoundingSettings(
                            storeId: store.id,
                            enabled: val,
                            increment: store.cashRoundingIncrement,
                            mode: store.cashRoundingMode,
                          );
                        },
                      ),

                      if (store.cashRoundingEnabled) ...[
                        const Divider(height: 24),

                        // Increment Selection
                        const Text(
                          'Kelipatan Pembulatan (Increment):',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 100, label: Text('Rp 100')),
                            ButtonSegment(value: 500, label: Text('Rp 500')),
                            ButtonSegment(value: 1000, label: Text('Rp 1.000')),
                          ],
                          selected: {store.cashRoundingIncrement},
                          onSelectionChanged: (set) {
                            storeRepo.updateCashRoundingSettings(
                              storeId: store.id,
                              enabled: true,
                              increment: set.first,
                              mode: store.cashRoundingMode,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mode Selection
                        const Text(
                          'Metode Pembulatan:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'ROUND_NEAREST',
                              label: Text('Terdekat'),
                              icon: Icon(Icons.compare_arrows_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'ROUND_UP',
                              label: Text('Ke Atas'),
                              icon: Icon(Icons.arrow_upward_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'ROUND_DOWN',
                              label: Text('Ke Bawah'),
                              icon: Icon(Icons.arrow_downward_rounded, size: 16),
                            ),
                          ],
                          selected: {store.cashRoundingMode},
                          onSelectionChanged: (set) {
                            storeRepo.updateCashRoundingSettings(
                              storeId: store.id,
                              enabled: true,
                              increment: store.cashRoundingIncrement,
                              mode: set.first,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store.cashRoundingMode == 'ROUND_NEAREST'
                              ? 'Membulatkan ke kelipatan terdekat (standar setengah ke atas)'
                              : store.cashRoundingMode == 'ROUND_UP'
                                  ? 'Membulatkan nilai sisa ke atas ke kelipatan berikutnya (Ceiling)'
                                  : 'Memotong sisa ke kelipatan di bawahnya (Floor)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Printer Settings Card (PRD 27)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.print_rounded,
                        color: Colors.indigo.shade700, size: 24),
                  ),
                  title: const Text(
                    'Pengaturan Printer Thermal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Hubungkan printer Bluetooth (58mm/80mm), salinan struk & auto-print',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                  onTap: () => context.push('/printers'),
                ),
              ),
              const SizedBox(height: 12),

              // Operational Mode & Cloud Sync Card
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCloud ? Colors.blue.shade300 : Colors.grey.shade200,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCloud ? Colors.blue.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCloud ? Icons.cloud_sync_rounded : Icons.storage_rounded,
                      color: isCloud ? Colors.blue.shade700 : Colors.grey.shade700,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      const Text(
                        'Mode Operasional',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCloud ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCloud ? 'CLOUD PRO' : 'LOKAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCloud ? Colors.blue.shade800 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    isCloud
                        ? 'Multi-device sync aktif (cloud_cache.sqlite)'
                        : 'Standalone offline (local.sqlite). Tekan untuk ganti mode atau sinkronisasi.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                  onTap: () => context.push('/cloud-sync'),
                ),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.backup_rounded,
                        color: Colors.teal.shade700, size: 24),
                  ),
                  title: const Text(
                    'Cadangkan & Pulihkan Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Export database lokal terenkripsi (.posbak) & restore data toko',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                  onTap: () => context.push('/backup'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
