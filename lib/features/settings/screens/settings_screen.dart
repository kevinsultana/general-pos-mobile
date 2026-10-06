import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../sync/controllers/sync_controller.dart';
import '../services/printer_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final syncCtrl = context.watch<SyncController>();
    final tenant = authCtrl.currentTenant;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Toko & Kasir',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Info Toko & Plan
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            backgroundColor: Colors.white.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tenant?.name ?? 'Nama Toko',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tenant?.isProOrPlus == true ? AppColors.primary50 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tenant?.isProOrPlus == true ? AppColors.primary : AppColors.slate300,
                        ),
                      ),
                      child: Text(
                        'PLAN: ${tenant?.plan ?? "FREE"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: tenant?.isProOrPlus == true ? AppColors.primaryDark : AppColors.slate700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Slug: /order/${tenant?.slug ?? ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                Text(
                  'Cabang: ${tenant?.branchName ?? "Cabang Utama"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Cloud Sync:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      tenant?.isProOrPlus == true ? 'Aktif (Cloud Connected)' : 'Nonaktif (Offline Local Only)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tenant?.isProOrPlus == true ? AppColors.success : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Sinkronisasi Cloud & Cek Upgrade
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            backgroundColor: Colors.white.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sync_rounded, color: AppColors.primaryDark, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Sinkronisasi Cloud Server',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Jika Anda telah melakukan upgrade ke Paket Plus / Pro di web dashboard, tekan tombol di bawah ini untuk memeriksa status dan mengunggah data lokal ke server PostgreSQL.',
                  style: TextStyle(fontSize: 11, color: AppColors.slate600, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate900,
                          side: const BorderSide(color: AppColors.slate300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Cek Upgrade Server', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: syncCtrl.isSyncing
                            ? null
                            : () async {
                                await authCtrl.refreshTenantPlan();
                                if (context.mounted && tenant != null) {
                                  await syncCtrl.syncIfUpgraded(context, tenant);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Printer Thermal Bluetooth
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            backgroundColor: Colors.white.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print_rounded, color: AppColors.slate700, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Printer Thermal Kasir',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  PrinterService.instance.isConnected
                      ? 'Terhubung ke: ${PrinterService.instance.connectedDeviceName}'
                      : 'Koneksi: Driver Siap (Mode Thermal 58mm)',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate100,
                    foregroundColor: AppColors.slate800,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
                  label: const Text('Simulasi Test Printer Struk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test print struk berhasil dikirim ke printer console!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Info Server URL
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            backgroundColor: Colors.white.withOpacity(0.9),
            child: Row(
              children: [
                const Icon(Icons.dns_outlined, color: AppColors.slate500, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Backend Server URL', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                      Text(ApiConstants.baseUrl,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F2),
                foregroundColor: AppColors.danger,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Keluar dari Akun Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Keluar Akun?'),
                    content: const Text('Pastikan transaksi hari ini telah selesai.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Keluar', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await authCtrl.logout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
