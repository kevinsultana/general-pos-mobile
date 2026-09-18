import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../core/providers/database_providers.dart';

/// Login & Upgrade page for SaaS Multi-Tenant Cloud POS.
/// Supports both:
/// 1. Registering a new PRO Cloud Store (automatically migrating local offline data to Cloud).
/// 2. Logging in with existing Cloud Store credentials.
class CloudLoginPage extends ConsumerStatefulWidget {
  final int initialTab;
  const CloudLoginPage({super.key, this.initialTab = 0});

  @override
  ConsumerState<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends ConsumerState<CloudLoginPage> {
  final _formKey = GlobalKey<FormState>();

  // Mode: 0 = Daftar ke PRO (Register & Migrate), 1 = Masuk ke Cloud (Login)
  late int _selectedTab = widget.initialTab;

  // Controllers for Register
  final _storeNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Common Controllers
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loadingStatusText;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Auto-fill local store info if available
    try {
      final storeRepo = ref.read(storeRepositoryProvider);
      final currentStore = await storeRepo.getCurrentStore();
      if (currentStore != null) {
        if (_storeNameCtrl.text.isEmpty) {
          _storeNameCtrl.text = currentStore.name;
        }
        if (_ownerNameCtrl.text.isEmpty && currentStore.ownerName != null) {
          _ownerNameCtrl.text = currentStore.ownerName!;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _loadingStatusText = _selectedTab == 0
          ? 'Mendaftarkan akun toko ke Cloud Server...'
          : 'Menghubungkan ke Cloud...';
    });

    try {
      final tokens = ref.read(tokenStorageProvider);
      final deviceId = await ref.read(deviceIdProvider.future);
      const serverUrl = AppConfig.defaultBaseUrl;

      await tokens.saveServerConfig(
        serverUrl: serverUrl,
        deviceId: deviceId,
      );

      final storeRepo = ref.read(storeRepositoryProvider);
      final localStore = await storeRepo.getCurrentStore();
      final localStoreId = localStore?.id ?? 'store-default-01';

      if (_selectedTab == 0) {
        // ──── FLOW 1: DAFTAR KE PRO (REGISTER & AUTO-MIGRATE) ────
        final cloudUser = await ref.read(cloudAuthProvider.notifier).registerStore(
              storeName: _storeNameCtrl.text.trim(),
              ownerName: _ownerNameCtrl.text.trim(),
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text,
              email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            );

        // Migrate local offline data to Cloud
        setState(() {
          _loadingStatusText = 'Mensinkronkan data produk & transaksi lokal ke Cloud...';
        });

        final migrationService = ref.read(dataMigrationServiceProvider);
        await migrationService.migrateLocalToCloud(
          localStoreId: localStoreId,
          cloudStoreId: cloudUser.storeId,
          onProgress: (p) {
            if (mounted) {
              setState(() => _loadingStatusText = p.step);
            }
          },
        );

        // Switch permanently to Cloud Mode
        await tokens.setCloudMode(true);
        await tokens.setProMigrated(true);
        await ref
            .read(appOperationalModeProvider.notifier)
            .switchMode(AppOperationalMode.cloud);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '🎉 Selamat! Toko Anda kini resmi beralih ke Mode Cloud PRO. Seluruh data lokal telah tersinkronisasi.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          context.go('/');
        }
      } else {
        // ──── FLOW 2: LOGIN AKUN CLOUD YANG SUDAH ADA ────
        final user = await ref.read(cloudAuthProvider.notifier).login(
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text,
            );

        // Check if there are local offline items to migrate
        final migrationService = ref.read(dataMigrationServiceProvider);
        try {
          setState(() {
            _loadingStatusText = 'Memeriksa sinkronisasi data lokal...';
          });
          await migrationService.migrateLocalToCloud(
            localStoreId: localStoreId,
            cloudStoreId: user.storeId,
          );
        } catch (_) {}

        // Activate Cloud Mode
        await tokens.setCloudMode(true);
        await tokens.setProMigrated(true);
        await ref
            .read(appOperationalModeProvider.notifier)
            .switchMode(AppOperationalMode.cloud);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Berhasil masuk ke Cloud POS (Mode Cloud Aktif)'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/');
        }
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _selectedTab == 0 ? 'Daftar Cloud PRO' : 'Sinkronisasi Cloud',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.cloud_sync_rounded,
                          size: 38, color: cs.onPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedTab == 0 ? 'Upgrade Toko ke PRO' : 'Masuk ke Cloud POS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedTab == 0
                        ? 'Daftarkan akun Cloud PRO untuk menikmati sinkronisasi multi-kasir, kitchen, gudang, dan dashboard web.'
                        : 'Masuk dengan kredensial toko atau kasir untuk melanjutkan transaksi di Cloud.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab selector: [ Daftar Baru | Masuk ]
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _isLoading
                                ? null
                                : () => setState(() => _selectedTab = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0
                                    ? cs.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Daftar ke PRO Baru',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedTab == 0
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _isLoading
                                ? null
                                : () => setState(() => _selectedTab = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1
                                    ? cs.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Sudah Ada Akun (Masuk)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedTab == 1
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ──── FIELDS FOR REGISTER ────
                  if (_selectedTab == 0) ...[
                    _SectionLabel(label: 'Nama Toko'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _storeNameCtrl,
                      decoration: _inputDecoration(
                        context,
                        hint: 'Nama Toko / Usaha Anda',
                        icon: Icons.storefront_rounded,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nama toko wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    _SectionLabel(label: 'Nama Pemilik Toko'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _ownerNameCtrl,
                      decoration: _inputDecoration(
                        context,
                        hint: 'Nama Pemilik / Penanggung Jawab',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionLabel(label: 'Email (Opsional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        context,
                        hint: 'email@tokoanda.com',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ──── COMMON FIELDS: USERNAME & PASSWORD ────
                  _SectionLabel(label: 'Username'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: _inputDecoration(
                      context,
                      hint: _selectedTab == 0 ? 'Buat username login' : 'Username akun toko atau kasir',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Username wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),

                  _SectionLabel(label: 'Password'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: _inputDecoration(
                      context,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Password minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 16),

                  // Auto migration info notice
                  if (_selectedTab == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sync_rounded, color: cs.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Semua produk, kategori & transaksi lokal saat ini akan otomatis disinkronkan ke Cloud.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error message
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button with Loading & Status Text
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _onSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(_selectedTab == 0
                            ? Icons.rocket_launch_rounded
                            : Icons.cloud_done_rounded),
                    label: Text(
                      _isLoading
                          ? (_loadingStatusText ?? 'Memproses...')
                          : (_selectedTab == 0
                              ? 'Daftar & Migrasikan ke PRO'
                              : 'Masuk ke Cloud'),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: cs.primary),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
