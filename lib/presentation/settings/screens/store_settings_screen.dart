import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart' show Store;
import '../../../domain/models/store_ext.dart';
import '../../../domain/repositories/i_store_repository.dart';
import 'order_type_settings_screen.dart';
import 'cash_rounding_settings_screen.dart';

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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    const Icon(
                      Icons.storefront_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Menyiapkan Pengaturan Toko...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

          final isProActive =
              isCloud &&
              store.subscriptionPlan == 'PRO' &&
              store.subscriptionStatus == 'ACTIVE';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Store Profile Card (Clickable to Edit Details)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  key: const Key('store_profile_card_tap'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showEditStoreDialog(context, store, storeRepo),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: const Icon(
                                Icons.store_rounded,
                                size: 28,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          store.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 13,
                                              color: AppColors.primary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (store.ownerName != null &&
                                      store.ownerName!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline_rounded,
                                          size: 13,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Pemilik: ${store.ownerName}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Alamat
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (store.address != null &&
                                        store.address!.trim().isNotEmpty)
                                    ? store.address!
                                    : 'Alamat belum diatur (ketuk untuk mengisi)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      (store.address != null &&
                                          store.address!.trim().isNotEmpty)
                                      ? AppColors.textPrimaryLight
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Nomor Telepon
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (store.phone != null &&
                                        store.phone!.trim().isNotEmpty)
                                    ? store.phone!
                                    : 'Nomor telepon belum diatur (ketuk untuk mengisi)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      (store.phone != null &&
                                          store.phone!.trim().isNotEmpty)
                                      ? AppColors.textPrimaryLight
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Metadata & Status Badges
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              isCloud
                                  ? 'Mata Uang: ${store.currency} | Mode Cloud'
                                  : 'Mata Uang: ${store.currency}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            if (isCloud)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isProActive
                                      ? Colors.green.shade50
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isProActive
                                        ? Colors.green.shade300
                                        : Colors.amber.shade300,
                                  ),
                                ),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  children: [
                                    Icon(
                                      isProActive
                                          ? Icons.verified_rounded
                                          : Icons.lock_clock_outlined,
                                      size: 13,
                                      color: isProActive
                                          ? Colors.green.shade800
                                          : Colors.amber.shade900,
                                    ),
                                    Text(
                                      isProActive
                                          ? 'Paket PRO Aktif'
                                          : 'Paket PRO Tidak Aktif',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isProActive
                                            ? Colors.green.shade900
                                            : Colors.amber.shade900,
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
                ),
              ),

              // Banner Penjelasan Jika Mode Cloud tapi Paket PRO Tidak Aktif
              if (isCloud && !isProActive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Langganan PRO Belum Aktif',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Fitur sinkronisasi multi-kasir otomatis aktif setelah toko Anda berlangganan paket PRO di Cloud Server.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900.withValues(
                                  alpha: 0.85,
                                ),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => context.push('/cloud-sync'),
                              child: const Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    'Cek Status Langganan Cloud',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Card Promo Daftar ke PRO (hanya ditampilkan jika dalam Mode Lokal)
              if (!isCloud) ...[
                const SizedBox(height: 14),
                _buildProPromotionCard(context),
              ],
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
                            content: Text(
                              val
                                  ? 'Modul Pelanggan diaktifkan'
                                  : 'Modul Pelanggan dinonaktifkan',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),

                    // Order Type Navigation Tile
                    ListTile(
                      key: const Key('order_type_settings_tile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.room_service_rounded,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      title: const Text(
                        'Pilihan Tipe Pesanan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        store.orderTypeEnabled
                            ? 'Aktif • ${store.orderTypesList.length} opsi (${store.orderTypesList.join(", ")})'
                            : 'Nonaktif • Ketuk untuk mengatur tipe pesanan',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: store.orderTypeEnabled
                                  ? Colors.teal.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: store.orderTypeEnabled
                                    ? Colors.teal.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              store.orderTypeEnabled ? 'AKTIF' : 'NONAKTIF',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: store.orderTypeEnabled
                                    ? Colors.teal.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      onTap: () {
                        try {
                          context.push('/order-types');
                        } catch (_) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OrderTypeSettingsScreen(),
                            ),
                          );
                        }
                      },
                    ),

                    const Divider(height: 1),

                    // Cash Rounding Navigation Tile
                    ListTile(
                      key: const Key('cash_rounding_settings_tile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.price_change_rounded,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      title: const Text(
                        'Pembulatan Tunai',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        store.cashRoundingEnabled
                            ? 'Aktif • Kelipatan Rp ${store.cashRoundingIncrement} (${store.cashRoundingMode == "ROUND_NEAREST" ? "Terdekat" : store.cashRoundingMode == "ROUND_UP" ? "Ke Atas" : "Ke Bawah"})'
                            : 'Nonaktif • Ketuk untuk mengatur pembulatan kasir',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: store.cashRoundingEnabled
                                  ? Colors.teal.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: store.cashRoundingEnabled
                                    ? Colors.teal.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              store.cashRoundingEnabled ? 'AKTIF' : 'NONAKTIF',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: store.cashRoundingEnabled
                                    ? Colors.teal.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      onTap: () {
                        try {
                          context.push('/cash-rounding');
                        } catch (_) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CashRoundingSettingsScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Printer Settings Card (PRD 27)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: Colors.indigo.shade700,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Pengaturan Printer Thermal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Hubungkan printer Bluetooth (58mm/80mm), salinan struk & auto-print',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () => context.push('/printers'),
                ),
              ),
              const SizedBox(height: 12),

              // Operational Mode & Cloud Sync Card (hanya untuk Mode Cloud)
              if (isCloud) ...[
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.blue.shade300,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    title: Row(
                      children: [
                        const Text(
                          'Layanan Cloud & Sync',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CLOUD PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'Multi-device sync aktif. Tekan untuk melihat status sinkronisasi.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () => context.push('/cloud-sync'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.backup_rounded,
                      color: Colors.teal.shade700,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Cadangkan & Pulihkan Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Export file cadangan terenkripsi (.posbak) & pulihkan data toko',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () => context.push('/backup'),
                ),
              ),
              const SizedBox(height: 12),

              // Reset Application Database Card (Simulasi Pengguna Baru)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Reset Semua Data Aplikasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.danger,
                    ),
                  ),
                  subtitle: const Text(
                    'Kosongkan semua database & token (simulasi pengguna baru pertama kali unduh)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.red,
                  ),
                  onTap: () => _showResetConfirmationDialog(context, ref),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Reset Semua Data?'),
          ],
        ),
        content: const Text(
          'Tindakan ini akan menghapus semua database lokal, cache cloud, dan sesi login pada aplikasi.\n\nAplikasi akan dikembalikan ke kondisi awal (seperti baru di-download) sehingga Anda dapat memulai simulasi kembali dari nol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final resetService = ref.read(dataResetServiceProvider);
                await resetService.resetEverything();
                ref.invalidate(appOperationalModeProvider);
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('✅ Seluruh database aplikasi berhasil di-reset bersih.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.go('/mode-select');
                }
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Gagal me-reset: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Reset Semua'),
          ),
        ],
      ),
    );
  }

  void _showEditStoreDialog(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: store.name);
    final addressController = TextEditingController(text: store.address ?? '');
    final phoneController = TextEditingController(text: store.phone ?? '');
    final ownerController = TextEditingController(text: store.ownerName ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (builderCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Edit Informasi Toko',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 4),
                        // Nama Toko
                        TextFormField(
                          key: const Key('edit_store_name_field'),
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nama Toko *',
                            hintText: 'Nama toko Anda',
                            prefixIcon: const Icon(Icons.storefront_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama toko wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Alamat
                        TextFormField(
                          key: const Key('edit_store_address_field'),
                          controller: addressController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Alamat Toko *',
                            hintText: 'Jl. Contoh No. 123',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Alamat toko wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Telepon
                        TextFormField(
                          key: const Key('edit_store_phone_field'),
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor Telepon / WhatsApp *',
                            hintText: '081234567890',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nomor telepon wajib diisi';
                            }
                            if (val.trim().length < 6) {
                              return 'Nomor telepon minimal 6 digit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Nama Pemilik
                        TextFormField(
                          key: const Key('edit_store_owner_field'),
                          controller: ownerController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nama Pemilik (Opsional)',
                            hintText: 'Nama pemilik toko',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  key: const Key('save_store_details_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            await storeRepo.updateStoreProfile(
                              storeId: store.id,
                              name: nameController.text.trim(),
                              address: addressController.text.trim(),
                              phone: phoneController.text.trim(),
                              ownerName: ownerController.text.trim().isNotEmpty
                                  ? ownerController.text.trim()
                                  : null,
                            );
                            if (context.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Detail toko berhasil diperbarui',
                                  ),
                                  backgroundColor: AppColors.accent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (builderCtx.mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(builderCtx).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal memperbarui toko: $e'),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  Widget _buildProPromotionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar ke General POS PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tingkatkan produktivitas bisnis Anda',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _proFeatureRow(
                    icon: Icons.cloud_sync_rounded,
                    title: 'Cloud Sync Otomatis',
                    desc: 'Data produk & penjualan tersimpan aman di cloud',
                  ),
                  const SizedBox(height: 8),
                  _proFeatureRow(
                    icon: Icons.point_of_sale_rounded,
                    title: 'Multi Kasir & Multi Device',
                    desc: 'Hubungkan banyak perangkat kasir dalam 1 toko',
                  ),
                  const SizedBox(height: 8),
                  _proFeatureRow(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Web Dashboard & Laporan',
                    desc: 'Pantau laporan bisnis dari laptop / browser',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: const Color(0xFF1E1B4B),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text(
                  'Daftar ke PRO Sekarang',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => context.push('/cloud-login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
