import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/cloud_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';

class AppSidebarDrawer extends ConsumerWidget {
  const AppSidebarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCloud = ref.watch(isCloudModeProvider);
    final storeAsync = ref.watch(currentStoreStreamProvider);
    final storeName = storeAsync.value?.name ?? 'General POS';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                20,
              ),
              decoration: BoxDecoration(
                gradient: isCloud
                    ? AppColors.indigoGradient
                    : AppColors.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCloud
                              ? Icons.cloud_done_rounded
                              : Icons.storefront_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCloud ? 'MODE CLOUD' : 'MODE LOKAL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCloud
                        ? 'Multi-Kasir • Sinkronisasi Aktif'
                        : 'Kasir Mandiri • Offline Database',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildNavTile(
                    context,
                    icon: Icons.home_rounded,
                    title: 'Beranda Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.point_of_sale_rounded,
                    title: 'Kasir POS',
                    highlight: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/pos');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Riwayat Transaksi',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/transactions');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.inventory_2_rounded,
                    title: 'Katalog Produk & Varian',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/products');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.people_alt_rounded,
                    title: 'Daftar Pelanggan',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/customers');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.local_offer_rounded,
                    title: 'Promosi & Diskon',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/promotions');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.insights_rounded,
                    title: 'Laporan & Analisis',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/reports');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.print_rounded,
                    title: 'Printer Thermal',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/printers');
                    },
                  ),

                  // Cloud Services (Exclusive in Cloud Mode)
                  if (isCloud) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'LAYANAN CLOUD PRO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.indigo,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildNavTile(
                      context,
                      icon: Icons.cloud_sync_rounded,
                      title: 'Sinkronisasi Cloud',
                      iconColor: AppColors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/cloud-sync');
                      },
                    ),
                  ],

                  const Divider(height: 24),
                  _buildNavTile(
                    context,
                    icon: Icons.backup_rounded,
                    title: 'Cadangkan & Pulihkan',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/backup');
                    },
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Pengaturan Toko',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),

            // Footer Mode Switcher
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Column(
                children: [
                  if (!isCloud) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.indigo,
                          side: const BorderSide(color: AppColors.indigo),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text(
                          'Beralih ke Mode Cloud',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final tokens = ref.read(tokenStorageProvider);
                          final token = await tokens.getAccessToken();
                          if (token != null && token.isNotEmpty) {
                            await tokens.setCloudMode(true);
                            await ref
                                .read(appOperationalModeProvider.notifier)
                                .switchMode(AppOperationalMode.cloud);
                          } else {
                            if (context.mounted) {
                              context.push('/cloud-login');
                            }
                          }
                        },
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondaryLight,
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.storefront_rounded, size: 18),
                        label: const Text(
                          'Beralih ke Mode Lokal',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final tokens = ref.read(tokenStorageProvider);
                          await tokens.setCloudMode(false);
                          await ref
                              .read(appOperationalModeProvider.notifier)
                              .switchMode(AppOperationalMode.local);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text(
                        'Pilih Mode Operasional',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/mode-select');
                      },
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

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: highlight ? AppColors.accent.withValues(alpha: 0.1) : null,
        leading: Icon(
          icon,
          size: 20,
          color: highlight
              ? AppColors.accent
              : (iconColor ?? AppColors.textSecondaryLight),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            color: highlight ? AppColors.accent : AppColors.textPrimaryLight,
          ),
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}
