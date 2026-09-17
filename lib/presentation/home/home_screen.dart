import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/cloud_providers.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/services/cash_rounding_calculator.dart';
import '../../l10n/app_localizations.dart';
import '../common/widgets/app_sidebar_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final int _testAmount = 9997;
  final bool _roundingEnabled = true;
  final int _increment = 1000;
  final CashRoundingMode _mode = CashRoundingMode.roundNearest;

  final CashRoundingCalculator _calculator = const CashRoundingCalculator();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCloudMode = ref.watch(isCloudModeProvider);
    final canCreateTransaction = ref.watch(
      hasPermissionProvider(AppPermissions.createTransaction),
    );
    final canManageProducts = ref.watch(
      hasAnyPermissionProvider([
        AppPermissions.manageProducts,
        AppPermissions.manageInventory,
        'view_products',
      ]),
    );
    final canViewTransactions = ref.watch(
      hasAnyPermissionProvider([
        AppPermissions.createTransaction,
        AppPermissions.viewReports,
        AppPermissions.refundTransaction,
      ]),
    );
    final canManageCustomers = ref.watch(
      hasAnyPermissionProvider([
        AppPermissions.manageCustomers,
        AppPermissions.createTransaction,
      ]),
    );
    final canManagePromotions = ref.watch(
      hasPermissionProvider(AppPermissions.managePromotions),
    );
    final canViewReports = ref.watch(
      hasPermissionProvider(AppPermissions.viewReports),
    );
    final canManageSettings = ref.watch(
      hasPermissionProvider(AppPermissions.manageSettings),
    );

    _calculator.calculate(
      amount: _testAmount,
      mode: _mode,
      increment: _increment,
      enabled: _roundingEnabled,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: const AppSidebarDrawer(),
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu Utama',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n?.appTitle ?? 'UMKM POS',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        actions: [
          if (isCloudMode)
            IconButton(
              icon: const Icon(
                Icons.cloud_sync_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'Status Cloud Sync',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => context.push('/cloud-sync'),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/mode-select'),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCloudMode
                    ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCloudMode
                      ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCloudMode
                        ? Icons.cloud_done_rounded
                        : Icons.offline_pin_rounded,
                    size: 13,
                    color: isCloudMode
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCloudMode ? 'Cloud' : 'Lokal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCloudMode
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n?.settings ?? 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Kasir POS Action Banner
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: canCreateTransaction
                      ? () => context.push('/pos')
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Anda tidak memiliki izin kasir (create_transaction)',
                              ),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.point_of_sale_rounded,
                                color: AppColors.accentLight,
                                size: 28,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    canCreateTransaction
                                        ? Icons.flash_on_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 14,
                                    color: canCreateTransaction
                                        ? Colors.amber
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    canCreateTransaction
                                        ? 'Buka Kasir'
                                        : 'Akses Dibatasi',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Text(
                              'Kasir POS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.accentLight,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mulai transaksi kasir, keranjang belanja, diskon baris & order, dan draft pesanan.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section: Menu Operasional
            const Text(
              'Menu Operasional Toko',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // 2-Column Operational Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                if (canManageProducts)
                  _buildMenuTile(
                    context,
                    title: 'Katalog & Inventori',
                    subtitle: 'Produk & stok',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.accent,
                    containerColor: AppColors.accentContainer,
                    route: '/products',
                  ),
                if (canViewTransactions)
                  _buildMenuTile(
                    context,
                    title: 'Riwayat Transaksi',
                    subtitle: 'Struk & refund',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.purple.shade700,
                    containerColor: Colors.purple.shade50,
                    route: '/transactions',
                  ),
                if (canManageCustomers)
                  _buildMenuTile(
                    context,
                    title: 'Daftar Pelanggan',
                    subtitle: 'Database pembeli',
                    icon: Icons.people_alt_rounded,
                    color: Colors.blue.shade700,
                    containerColor: Colors.blue.shade50,
                    route: '/customers',
                  ),
                if (canManagePromotions)
                  _buildMenuTile(
                    context,
                    title: 'Promosi & Voucher',
                    subtitle: 'Diskon belanja',
                    icon: Icons.local_offer_rounded,
                    color: Colors.orange.shade800,
                    containerColor: Colors.orange.shade50,
                    route: '/promotions',
                  ),
                if (canViewReports)
                  _buildMenuTile(
                    context,
                    title: 'Laporan & Analisis',
                    subtitle: 'Omzet & laba kotor',
                    icon: Icons.insights_rounded,
                    color: Colors.teal.shade700,
                    containerColor: Colors.teal.shade50,
                    route: '/reports',
                  ),
                _buildMenuTile(
                  context,
                  title: 'Printer Thermal',
                  subtitle: 'Struk Bluetooth',
                  icon: Icons.print_rounded,
                  color: Colors.indigo.shade700,
                  containerColor: Colors.indigo.shade50,
                  route: '/printers',
                ),
                if (isCloudMode)
                  _buildMenuTile(
                    context,
                    title: 'Sinkronisasi Cloud',
                    subtitle: 'Multi-device sync',
                    icon: Icons.cloud_sync_rounded,
                    color: Colors.cyan.shade700,
                    containerColor: Colors.cyan.shade50,
                    route: '/cloud-sync',
                  ),
                if (canManageSettings)
                  _buildMenuTile(
                    context,
                    title: 'Cadangkan & Pulihkan',
                    subtitle: 'Backup enkripsi',
                    icon: Icons.backup_rounded,
                    color: Colors.blueGrey.shade700,
                    containerColor: Colors.blueGrey.shade50,
                    route: '/backup',
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color containerColor,
    required String route,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
