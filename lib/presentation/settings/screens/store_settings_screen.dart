import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart' show Store;
import '../../../domain/models/store_ext.dart';
import '../../../domain/repositories/i_store_repository.dart';

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
                              'Mata Uang: ${store.currency} | ${isCloud ? 'Mode Cloud' : 'Mode Lokal'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
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

              // Banner Penjelasan Jika Paket PRO Tidak Aktif
              if (!isProActive) ...[
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
                              'Paket PRO Tidak Aktif (Mode Lokal)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Fitur paket PRO dan sinkronisasi multi-kasir otomatis aktif setelah Anda mendaftarkan atau menyinkronkan toko ke Cloud Server.',
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
                                    'Daftar / Sinkronisasi Cloud Sekarang',
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

                    // Order Type Toggle
                    SwitchListTile(
                      key: const Key('order_type_switch'),
                      secondary: Container(
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
                      subtitle: const Text(
                        'Aktifkan untuk menampilkan pilihan tipe pesanan (Dine In, Takeaway, dll.) pada transaksi kasir POS.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: store.orderTypeEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) async {
                        final messenger = ScaffoldMessenger.of(context);
                        await storeRepo.setOrderTypeEnabled(store.id, val);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? 'Pilihan Tipe Pesanan diaktifkan'
                                  : 'Pilihan Tipe Pesanan dinonaktifkan',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),

                    // Order Type Options CRUD (visible when orderTypeEnabled is true)
                    if (store.orderTypeEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 340;
                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Daftar Pilihan Aktif:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  _confirmResetOrderTypes(
                                                      context,
                                                      store,
                                                      storeRepo),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              child: const Text('Reset Default',
                                                  style: TextStyle(fontSize: 11)),
                                            ),
                                            FilledButton.tonalIcon(
                                              key: const Key(
                                                  'add_order_type_button'),
                                              style: FilledButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              onPressed: () =>
                                                  _showAddOrderTypeDialog(
                                                      context, store, storeRepo),
                                              icon: const Icon(Icons.add_rounded,
                                                  size: 14),
                                              label: const Text('Tambah Opsi',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Daftar Pilihan Aktif:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _confirmResetOrderTypes(
                                                    context, store, storeRepo),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            child: const Text('Reset Default',
                                                style: TextStyle(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 4),
                                          FilledButton.tonalIcon(
                                            key: const Key(
                                                'add_order_type_button'),
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            onPressed: () =>
                                                _showAddOrderTypeDialog(
                                                    context, store, storeRepo),
                                            icon: const Icon(Icons.add_rounded,
                                                size: 14),
                                            label: const Text('Tambah Opsi',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: store.orderTypesList.map((opt) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          opt,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _showEditOrderTypeDialog(
                                              context, store, storeRepo, opt),
                                          borderRadius: BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(Icons.edit_outlined,
                                                size: 14,
                                                color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        InkWell(
                                          onTap: () => _deleteOrderType(
                                              context, store, storeRepo, opt),
                                          borderRadius: BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(Icons.close_rounded,
                                                size: 14,
                                                color: AppColors.danger),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                              icon: Icon(
                                Icons.compare_arrows_rounded,
                                size: 16,
                              ),
                            ),
                            ButtonSegment(
                              value: 'ROUND_UP',
                              label: Text('Ke Atas'),
                              icon: Icon(Icons.arrow_upward_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'ROUND_DOWN',
                              label: Text('Ke Bawah'),
                              icon: Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                              ),
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

              // Operational Mode & Cloud Sync Card
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCloud
                        ? Colors.blue.shade300
                        : Colors.grey.shade200,
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
                      color: isCloud
                          ? Colors.blue.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCloud
                          ? Icons.cloud_sync_rounded
                          : Icons.storage_rounded,
                      color: isCloud
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      const Text(
                        'Mode Operasional',
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
                          color: isCloud
                              ? Colors.blue.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCloud ? 'CLOUD PRO' : 'LOKAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCloud
                                ? Colors.blue.shade800
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    isCloud ? 'Multi-device sync aktif (cloud_cache.sqlite)' : 'Standalone offline (local.sqlite). Tekan untuk ganti mode atau sinkronisasi.',
                    style: const TextStyle(
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
                    'Export database lokal terenkripsi (.posbak) & restore data toko',
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
            ],
          );
        },
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

  Future<void> _showAddOrderTypeDialog(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Tipe Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Tipe Pesanan *',
                hintText: 'Cth: Ojol, Katering, Drive Thru',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) return 'Nama tipe pesanan tidak boleh kosong';
                final currentList = store.orderTypesList;
                if (currentList.any((e) => e.toLowerCase() == trimmed.toLowerCase())) {
                  return 'Tipe pesanan "$trimmed" sudah ada';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newType = controller.text.trim();
                final updatedList = [...store.orderTypesList, newType];
                await storeRepo.updateOrderTypes(
                  storeId: store.id,
                  orderTypes: updatedList,
                );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tipe pesanan "$newType" berhasil ditambahkan'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditOrderTypeDialog(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Tipe Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Tipe Pesanan *',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) return 'Nama tipe pesanan tidak boleh kosong';
                if (trimmed.toLowerCase() != oldName.toLowerCase()) {
                  final currentList = store.orderTypesList;
                  if (currentList
                      .any((e) => e.toLowerCase() == trimmed.toLowerCase())) {
                    return 'Tipe pesanan "$trimmed" sudah ada';
                  }
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final updatedName = controller.text.trim();
                final updatedList = store.orderTypesList
                    .map((e) => e == oldName ? updatedName : e)
                    .toList();
                await storeRepo.updateOrderTypes(
                  storeId: store.id,
                  orderTypes: updatedList,
                );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Tipe pesanan berhasil diubah menjadi "$updatedName"'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOrderType(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
    String targetName,
  ) async {
    final currentList = store.orderTypesList;
    if (currentList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 tipe pesanan yang aktif.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final updatedList = currentList.where((e) => e != targetName).toList();
    await storeRepo.updateOrderTypes(
      storeId: store.id,
      orderTypes: updatedList,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tipe pesanan "$targetName" dihapus'),
          action: SnackBarAction(
            label: 'Batal',
            onPressed: () async {
              await storeRepo.updateOrderTypes(
                storeId: store.id,
                orderTypes: currentList,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _confirmResetOrderTypes(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Tipe Pesanan?'),
        content: const Text(
          'Kembalikan daftar pilihan tipe pesanan ke default:\n• Dine In\n• Takeaway\n• Delivery\n• Online',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await storeRepo.updateOrderTypes(
        storeId: store.id,
        orderTypes: const ['Dine In', 'Takeaway', 'Delivery', 'Online'],
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilihan tipe pesanan dikembalikan ke default'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }
}
