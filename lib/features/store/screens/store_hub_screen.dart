import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../customers/screens/customer_screen.dart';
import '../../products/screens/product_list_screen.dart';
import '../../promotions/screens/promotion_screen.dart';
import '../../qr_menu/screens/qr_menu_screen.dart';
import '../../upgrade/screens/upgrade_screen.dart';

class StoreHubScreen extends StatelessWidget {
  const StoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<AuthController>().currentTenant;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        title: const Text(
          'Manajemen Toko & Fitur',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.slate900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Toko
          GlassCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(18),
            backgroundColor: AppColors.slate900,
            borderColor: AppColors.slate800,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant?.name ?? 'OmniPOS Store',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Paket: ${tenant?.plan ?? "FREE"} • ${tenant?.branchName ?? "Cabang Utama"}',
                        style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'MENU OPERASIONAL TOKO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.slate500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // 1. Pelanggan
          _buildHubTile(
            context,
            icon: Icons.people_alt_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            title: 'Daftar Pelanggan (CRM)',
            subtitle: 'Kelola kontak pembeli, nomor WhatsApp, dan riwayat pesanan',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CustomerScreen()));
            },
          ),
          const SizedBox(height: 10),

          // 2. Kupon Promo
          _buildHubTile(
            context,
            icon: Icons.confirmation_num_rounded,
            iconBgColor: AppColors.primary50,
            iconColor: AppColors.primaryDark,
            title: 'Kupon & Promo Diskon',
            subtitle: 'Atur potongan harga, diskon persentase, dan nominal belanja',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const PromotionScreen()));
            },
          ),
          const SizedBox(height: 10),

          // 3. QR Menu Self-Order
          _buildHubTile(
            context,
            icon: Icons.qr_code_2_rounded,
            iconBgColor: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'QR Menu & Self-Ordering',
            subtitle: 'Tampilkan QR Code untuk pemesanan mandiri oleh pelanggan di meja',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const QrMenuScreen()));
            },
          ),
          const SizedBox(height: 10),

          // 4. Katalog Produk
          _buildHubTile(
            context,
            icon: Icons.inventory_2_rounded,
            iconBgColor: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            title: 'Katalog Produk & Kategori',
            subtitle: 'Tambah item menu, foto, harga, modal, dan stok produk lokal',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ProductListScreen()));
            },
          ),
          const SizedBox(height: 10),

          // 5. Upgrade Plan
          _buildHubTile(
            context,
            icon: Icons.workspace_premium_rounded,
            iconBgColor: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFD97706),
            title: 'Paket & Langganan Toko',
            subtitle: 'Perbandingan fitur Free vs Plus vs Pro dan status cloud sync',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const UpgradeScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubTile(
    BuildContext context, {
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      backgroundColor: Colors.white.withOpacity(0.92),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.3),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate400, size: 20),
        ],
      ),
    );
  }
}
