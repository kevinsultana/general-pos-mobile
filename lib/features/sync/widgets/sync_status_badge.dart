import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/sync_controller.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  void _showSyncModal(BuildContext context) {
    final authCtrl = context.read<AuthController>();
    final syncCtrl = context.read<SyncController>();
    final tenant = authCtrl.currentTenant;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  tenant?.isProOrPlus == true ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
                  color: tenant?.isProOrPlus == true ? AppColors.success : AppColors.primaryDark,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  tenant?.isProOrPlus == true ? 'Cloud Sync Mode (Plus/Pro)' : 'Offline Local Mode (Free Plan)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tenant?.isProOrPlus == true
                  ? 'Aplikasi terhubung ke server cloud. Transaksi offline akan otomatis disinkronkan ke PostgreSQL saat online.'
                  : 'Pada Free Plan, semua katalog & riwayat transaksi disimpan 100% di SQLite lokal HP Anda tanpa membebani kuota server cloud.',
              style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Data Pending Sinkronisasi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    '${syncCtrl.pendingCount} Item',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: syncCtrl.pendingCount > 0 ? AppColors.primaryDark : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: syncCtrl.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(
                  tenant?.isProOrPlus == true ? 'Sinkronkan Sekarang' : 'Cek Status Upgrade Akun',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: syncCtrl.isSyncing
                    ? null
                    : () async {
                        await authCtrl.refreshTenantPlan();
                        if (context.mounted && tenant != null) {
                          await syncCtrl.syncIfUpgraded(context, tenant);
                        }
                        if (context.mounted) Navigator.pop(ctx);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final syncCtrl = context.watch<SyncController>();
    final tenant = authCtrl.currentTenant;
    final isPro = tenant?.isProOrPlus ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showSyncModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPro ? const Color(0xFFECFDF5) : AppColors.primary50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPro ? const Color(0xFFA7F3D0) : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPro ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
              size: 12,
              color: isPro ? AppColors.success : AppColors.primaryDark,
            ),
            const SizedBox(width: 4),
            Text(
              isPro ? (syncCtrl.isSyncing ? 'Syncing...' : 'Pro Cloud') : 'Free SQLite',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isPro ? AppColors.success : AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
