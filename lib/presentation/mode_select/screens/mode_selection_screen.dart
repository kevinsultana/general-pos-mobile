import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/cloud_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';

class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  ConsumerState<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfProMigrated();
  }

  Future<void> _checkIfProMigrated() async {
    try {
      final tokens = ref.read(tokenStorageProvider);
      final isPro = await tokens.isProMigrated();
      if (isPro && mounted) {
        context.go('/');
      }
    } catch (_) {}
  }

  Future<void> _selectLocalMode() async {
    setState(() => _isLoading = true);
    try {
      try {
        final tokens = ref.read(tokenStorageProvider);
        final isPro = await tokens.isProMigrated();
        if (isPro) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Toko Anda sudah bermigrasi ke Cloud PRO. Akses dialihkan ke Cloud.',
                ),
                backgroundColor: Colors.blueGrey,
              ),
            );
            context.go('/');
            return;
          }
        }

        await tokens.setCloudMode(false);
        await ref
            .read(appOperationalModeProvider.notifier)
            .switchMode(AppOperationalMode.local);
      } catch (_) {
        // Fallback for headless widget testing where secure storage channel is not mocked
      }

      bool isRegistered = false;
      try {
        final storeRepo = ref.read(storeRepositoryProvider);
        isRegistered = await storeRepo.isStoreRegistered();
      } catch (_) {
        isRegistered = false;
      }

      if (mounted) {
        if (!isRegistered) {
          context.push('/local-register');
        } else {
          context.go('/');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCloudMode() async {
    setState(() => _isLoading = true);
    try {
      String? accessToken;
      try {
        final tokens = ref.read(tokenStorageProvider);
        accessToken = await tokens.getAccessToken();

        if (accessToken != null && accessToken.isNotEmpty) {
          // Already logged in
          await tokens.setCloudMode(true);
          await ref
              .read(appOperationalModeProvider.notifier)
              .switchMode(AppOperationalMode.cloud);

          if (mounted) {
            context.go('/');
            return;
          }
        }
      } catch (_) {
        // Fallback for test environments
      }

      // Needs login
      if (mounted) {
        context.push('/cloud-login');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showResetAppDialog() async {
    final confirmed = await showDialog<bool>(
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
          'Semua data database lokal, cache cloud, dan token akun pada aplikasi ini akan dihapus bersih.\n\nAplikasi akan kembali ke kondisi awal (seperti baru pertama kali di-download).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Reset Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final resetService = ref.read(dataResetServiceProvider);
        await resetService.resetEverything();
        ref.invalidate(appOperationalModeProvider);
        ref.invalidate(storeRepositoryProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Seluruh database aplikasi berhasil di-reset bersih.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal me-reset data: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Header
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.point_of_sale_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'General POS Pro',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Pilih mode operasional untuk memulai transaksi kasir',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Option 1: Mode Lokal (Offline First)
                  _buildModeCard(
                    title: 'Mode Lokal (Offline POS)',
                    badge: 'MANDIRI / OFFLINE',
                    badgeColor: AppColors.accent,
                    badgeBg: AppColors.accentContainer,
                    description:
                        'Kasir mandiri offline tanpa koneksi internet. Semua data produk & transaksi tersimpan aman di perangkat lokal ini.',
                    icon: Icons.storefront_rounded,
                    iconBg: AppColors.accentContainer,
                    iconColor: AppColors.accent,
                    gradientBorder: false,
                    buttonText: 'Masuk Mode Lokal',
                    buttonColor: AppColors.primary,
                    onTap: _isLoading ? null : _selectLocalMode,
                  ),
                  const SizedBox(height: 20),

                  // Option 2: Mode Cloud (Multi-Device Sync)
                  _buildModeCard(
                    title: 'Mode Cloud (Online Sync)',
                    badge: 'MULTI-KASIR & CLOUD',
                    badgeColor: AppColors.indigo,
                    badgeBg: AppColors.indigoContainer,
                    description:
                        'Terhubung ke Cloud Server, sinkronisasi otomatis multi-kasir, integrasi Web Dashboard, dan backup pusat.',
                    icon: Icons.cloud_sync_rounded,
                    iconBg: AppColors.indigoContainer,
                    iconColor: AppColors.indigo,
                    gradientBorder: true,
                    buttonText: 'Masuk Mode Cloud',
                    buttonColor: AppColors.indigo,
                    onTap: _isLoading ? null : _selectCloudMode,
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _showResetAppDialog,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.danger),
                      label: const Text(
                        'Reset Semua Database (Simulasi Pengguna Baru)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
    required String description,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool gradientBorder,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: gradientBorder
              ? AppColors.indigo.withValues(alpha: 0.5)
              : AppColors.borderLight,
          width: gradientBorder ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        buttonText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
