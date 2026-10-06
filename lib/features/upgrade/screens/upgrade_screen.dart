import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../sync/controllers/sync_controller.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  String _billingCycle = 'yearly'; // 'monthly' or 'yearly'

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final syncCtrl = context.watch<SyncController>();
    final tenant = authCtrl.currentTenant;
    final isYearly = _billingCycle == 'yearly';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Paket & Langganan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900)),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current Plan Status Card
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.slate900,
              borderColor: AppColors.slate800,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paket Toko Saat Ini:', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        tenant?.plan ?? 'FREE',
                        style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Cek Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await authCtrl.refreshTenantPlan();
                      if (context.mounted && tenant != null) {
                        await syncCtrl.syncIfUpgraded(context, tenant);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Billing Cycle Toggle (Bulanan vs Tahunan dengan badge Hemat 15% - persis seperti web app!)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(color: AppColors.slate900.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => setState(() => _billingCycle = 'monthly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: !isYearly ? AppColors.slate900 : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Bulanan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: !isYearly ? Colors.white : AppColors.slate600,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => setState(() => _billingCycle = 'yearly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isYearly ? AppColors.slate900 : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Tahunan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isYearly ? Colors.white : AppColors.slate600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isYearly ? AppColors.primary : AppColors.primary50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Hemat 15%',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isYearly ? AppColors.slate950 : AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Plan 1: FREE
            _buildPlanCard(
              title: 'FREE PLAN',
              price: 'Rp 0',
              period: '/ selamanya',
              badge: 'Aktif Bawaan',
              badgeColor: AppColors.slate100,
              textColor: AppColors.slate700,
              features: const [
                '100% Offline SQLite di HP',
                'Katalog Produk & Kategori Lokal',
                'Pencatatan Penjualan & Kasir POS',
                'Cetak Struk Thermal Bluetooth',
                '1 Cabang Toko',
              ],
              isCurrent: tenant?.plan == 'FREE',
            ),
            const SizedBox(height: 14),

            // Plan 2: PLUS
            _buildPlanCard(
              title: 'PLUS PLAN',
              price: isYearly ? 'Rp 84.150' : 'Rp 99.000',
              period: '/ bulan',
              badge: 'Populer',
              badgeColor: AppColors.primary50,
              textColor: AppColors.primaryDark,
              features: const [
                'Cloud Sync Otomatis ke PostgreSQL',
                'Database Cloud Aman & Terbackup',
                'Manajemen Pelanggan & Riwayat',
                'Kupon & Promo Diskon',
                'Bisa akses dari Web Dashboard & Mobile bersamaan',
              ],
              isCurrent: tenant?.plan == 'PLUS',
              isHighlight: true,
            ),
            const SizedBox(height: 14),

            // Plan 3: PRO
            _buildPlanCard(
              title: 'PRO PLAN',
              price: isYearly ? 'Rp 169.150' : 'Rp 199.000',
              period: '/ bulan',
              badge: 'Paling Lengkap',
              badgeColor: const Color(0xFFEFF6FF),
              textColor: AppColors.info,
              features: const [
                'Semua Fitur Plus Plan',
                'Multi Cabang / Outlet Toko',
                'Self-Ordering QR Menu untuk Pelanggan',
                'Laporan Analitik Lanjutan & Shift',
                'Dukungan Teknis Prioritas 24/7',
              ],
              isCurrent: tenant?.plan == 'PRO',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required String badge,
    required Color badgeColor,
    required Color textColor,
    required List<String> features,
    bool isCurrent = false,
    bool isHighlight = false,
  }) {
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(20),
      backgroundColor: Colors.white.withOpacity(0.95),
      borderColor: isHighlight ? AppColors.primary : Colors.white,
      borderWidth: isHighlight ? 2.0 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.slate900)),
              const SizedBox(width: 4),
              Text(period, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            ],
          ),
          const Divider(height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 12, color: AppColors.slate700)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? AppColors.slate200 : (isHighlight ? AppColors.primary : AppColors.slate900),
                foregroundColor: isCurrent ? AppColors.slate600 : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isCurrent
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Upgrade Paket'),
                          content: const Text(
                            'Untuk melakukan pembayaran Midtrans, Anda dapat membuka halaman /dashboard/upgrade di web dashboard atau melanjutkan pembayaran terpadu.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
                          ],
                        ),
                      );
                    },
              child: Text(
                isCurrent ? 'Paket Aktif Saat Ini' : 'Pilih Paket Ini',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
