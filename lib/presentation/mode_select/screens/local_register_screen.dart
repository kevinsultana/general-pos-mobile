import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';

class LocalRegisterScreen extends ConsumerStatefulWidget {
  const LocalRegisterScreen({super.key});

  @override
  ConsumerState<LocalRegisterScreen> createState() => _LocalRegisterScreenState();
}

class _LocalRegisterScreenState extends ConsumerState<LocalRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ownerNameController = TextEditingController();

  final _adminUsernameController = TextEditingController(text: 'admin');
  final _adminDisplayNameController = TextEditingController(text: 'Administrator');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _ownerNameController.dispose();
    _adminUsernameController.dispose();
    _adminDisplayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final storeRepo = ref.read(storeRepositoryProvider);
      final storeName = _storeNameController.text.trim();
      final address = _addressController.text.trim();
      final phone = _phoneController.text.trim();
      final ownerName = _ownerNameController.text.trim().isNotEmpty
          ? _ownerNameController.text.trim()
          : null;

      final adminUsername = _adminUsernameController.text.trim();
      final adminDisplayName = _adminDisplayNameController.text.trim().isNotEmpty
          ? _adminDisplayNameController.text.trim()
          : (ownerName ?? 'Administrator');
      final adminPassword = _passwordController.text;

      await storeRepo.registerLocalStore(
        name: storeName,
        address: address,
        phone: phone,
        ownerName: ownerName,
        adminUsername: adminUsername,
        adminPassword: adminPassword,
        adminDisplayName: adminDisplayName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toko "$storeName" berhasil didaftarkan! Selamat datang.',
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendaftarkan toko: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Registrasi Toko Lokal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Header
                    _buildHeaderBanner(),
                    const SizedBox(height: 20),

                    // Section 1: Store Information
                    _buildStoreSection(),
                    const SizedBox(height: 20),

                    // Section 2: Admin Account Credentials
                    _buildAdminSection(),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        key: const Key('local_register_submit_button'),
                        onPressed: _isLoading ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Simpan & Masuk Mode Kasir',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inisialisasi Toko Offline-First',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Daftarkan profil toko dan akun admin lokal. Data tersimpan aman di perangkat dan siap disinkronisasikan secara mulus ketika beralih ke Mode Cloud.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Informasi Toko',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Nama Toko
          TextFormField(
            key: const Key('local_register_store_name'),
            controller: _storeNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama Toko *',
              hintText: 'Contoh: Toko Berkah Mandiri',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          const SizedBox(height: 16),

          // Alamat
          TextFormField(
            key: const Key('local_register_store_address'),
            controller: _addressController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Alamat Toko *',
              hintText: 'Jl. Merdeka No. 123, Kel. Suka Makmur',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          const SizedBox(height: 16),

          // Nomor Telepon
          TextFormField(
            key: const Key('local_register_store_phone'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Nomor Telepon / WhatsApp *',
              hintText: '081234567890',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nomor telepon wajib diisi';
              }
              if (val.trim().length < 6) {
                return 'Nomor telepon tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Nama Pemilik (Opsional)
          TextFormField(
            key: const Key('local_register_owner_name'),
            controller: _ownerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama Pemilik (Opsional)',
              hintText: 'Contoh: H. Ahmad Santoso',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: AppColors.indigo, size: 20),
              SizedBox(width: 8),
              Text(
                'Akun Administrator Lokal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Akun ini digunakan untuk autentikasi dan pengaturan toko di perangkat.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const Divider(height: 24),

          // Username Admin
          TextFormField(
            key: const Key('local_register_admin_username'),
            controller: _adminUsernameController,
            decoration: InputDecoration(
              labelText: 'Username Admin *',
              hintText: 'admin',
              prefixIcon: const Icon(Icons.account_circle_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Username admin wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Display Name
          TextFormField(
            key: const Key('local_register_admin_display_name'),
            controller: _adminDisplayNameController,
            decoration: InputDecoration(
              labelText: 'Nama Tampilan Admin',
              hintText: 'Administrator',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
          ),
          const SizedBox(height: 16),

          // Temporary Password
          TextFormField(
            key: const Key('local_register_admin_password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password Sementara Admin *',
              hintText: 'Minimal 4 karakter atau PIN',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Password sementara wajib diisi';
              }
              if (val.length < 4) {
                return 'Password minimal 4 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            key: const Key('local_register_admin_confirm_password'),
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Konfirmasi Password *',
              hintText: 'Ulangi password di atas',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.backgroundLight,
            ),
            validator: (val) {
              if (val != _passwordController.text) {
                return 'Password konfirmasi tidak cocok';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
