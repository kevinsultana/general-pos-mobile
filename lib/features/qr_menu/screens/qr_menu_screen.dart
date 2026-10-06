import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';

class QrMenuScreen extends StatelessWidget {
  const QrMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<AuthController>().currentTenant;
    final slug = tenant?.slug ?? 'toko';
    final orderUrl = 'http://localhost:3000/order/$slug';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('QR Menu & Self-Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900)),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              backgroundColor: Colors.white.withOpacity(0.95),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primaryDark),
                        SizedBox(width: 6),
                        Text(
                          'Pemesanan Mandiri Pelanggan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tenant?.name ?? 'Toko Anda',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pelanggan dapat memindai QR code ini di meja atau kasir untuk membuka katalog digital dan memesan langsung dari HP mereka.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  // QR Code Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slate200),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.slate900.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: orderUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // URL Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 18, color: AppColors.slate500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            orderUrl,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.slate700),
                          tooltip: 'Salin Tautan',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: orderUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tautan katalog pesanan berhasil disalin!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Petunjuk Tambahan
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.white.withOpacity(0.9),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Pesanan online yang dibuat pelanggan melalui katalog web ini dapat langsung diproses dan diselesaikan pembayarannya di kasir POS mobile.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate600, height: 1.4),
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
}
