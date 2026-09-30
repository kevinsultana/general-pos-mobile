import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';

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
  final _serverUrlCtrl = TextEditingController();

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
    try {
      final tokens = ref.read(tokenStorageProvider);
      final storeId = await tokens.getStoreId();
      final isPaired = await tokens.isStorePaired();
      final tier = await tokens.getTier() ?? 'FREE';
      if (storeId != null && storeId.isNotEmpty && isPaired) {
        if (tier == 'PRO') {
          final cashierId = await tokens.getCashierUserId();
          if (cashierId != null && cashierId.isNotEmpty && mounted) {
            context.go('/');
            return;
          } else if (mounted) {
            context.go('/staff-login');
            return;
          }
        } else {
          // FREE tier: single user owner
          final userId = await tokens.getUserId();
          if (userId != null && userId.isNotEmpty && mounted) {
            context.go('/');
            return;
          }
        }
      }
    } catch (_) {}

    // Auto-fill local store info if available
    try {
      final tokens = ref.read(tokenStorageProvider);
      final savedUrl = await tokens.getServerUrl();
      _serverUrlCtrl.text = (savedUrl != null && savedUrl.isNotEmpty)
          ? savedUrl
          : AppConfig.defaultBaseUrl;

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
    _serverUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _loadingStatusText = _selectedTab == 0
          ? 'Mendaftarkan akun toko ke server...'
          : 'Menghubungkan ke server...';
    });

    try {
      final tokens = ref.read(tokenStorageProvider);
      final deviceId = await ref.read(deviceIdProvider.future);
      final serverUrl = AppConfig.normalizeUrl(
        _serverUrlCtrl.text.trim().isNotEmpty
            ? _serverUrlCtrl.text.trim()
            : AppConfig.defaultBaseUrl,
      );

      await tokens.saveServerConfig(
        serverUrl: serverUrl,
        deviceId: deviceId,
      );

      final storeRepo = ref.read(storeRepositoryProvider);
      final localStore = await storeRepo.getCurrentStore();
      final localStoreId = localStore?.id ?? 'store-default-01';

      if (_selectedTab == 0) {
        // ──── FLOW 1: DAFTAR TOKO BARU ────
        final cloudUser = await ref.read(cloudAuthProvider.notifier).registerStore(
              storeName: _storeNameCtrl.text.trim(),
              ownerName: _ownerNameCtrl.text.trim(),
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text,
              email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
            );

        // Bind authentic cloud store & owner into Drift SQLite (both local and cloud cache)
        setState(() {
          _loadingStatusText = 'Menyiapkan database kasir offline lokal...';
        });
        final localDb = ref.read(localDatabaseProvider);
        final cloudDb = ref.read(cloudCacheDatabaseProvider);

        for (final db in [localDb, cloudDb]) {
          await db.storeDao.ensureStoreWithId(
            id: cloudUser.storeId,
            name: cloudUser.storeName,
            subscriptionPlan: cloudUser.tier,
            subscriptionStatus: 'ACTIVE',
          );
          await db.storeDao.bindCloudStoreAndUser(
            storeId: cloudUser.storeId,
            storeName: cloudUser.storeName,
            subscriptionPlan: cloudUser.tier,
            userId: cloudUser.userId,
            username: cloudUser.username,
            displayName: cloudUser.displayName,
            ownerName: _ownerNameCtrl.text.trim().isNotEmpty
                ? _ownerNameCtrl.text.trim()
                : null,
          );
          await db.storeDao.healAllOrphanRecords(cloudUser.storeId);
        }
        await tokens.setStorePaired(true);

        if (cloudUser.tier == 'FREE' || !cloudUser.canCloudSync) {
          await tokens.saveCashierSession(
            userId: cloudUser.userId,
            username: cloudUser.username,
            displayName: cloudUser.displayName,
            role: 'OWNER',
            permissions: cloudUser.permissions,
          );
          await tokens.setCloudMode(false);
          await ref
              .read(appOperationalModeProvider.notifier)
              .switchMode(AppOperationalMode.local);
          try {
            ref.read(syncCoordinatorProvider).stopPeriodicSync();
          } catch (_) {}

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🎉 Pendaftaran Berhasil! Toko aktif dalam Mode Lokal (FREE). Kasir siap digunakan offline.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
            context.go('/');
          }
        } else {
          // PRO/PAID tier: Set cloud mode, clear cashier session, migrate local data, proceed to staff login
          await tokens.setCloudMode(true);
          await ref
              .read(appOperationalModeProvider.notifier)
              .switchMode(AppOperationalMode.cloud);
          await tokens.clearCashierSession();

          // Auto-migrate local offline data (products, categories, offline transactions) to cloud
          try {
            setState(() {
              _loadingStatusText = 'Menyelaraskan data offline & transaksi ke Cloud...';
            });
            final migrationService = ref.read(dataMigrationServiceProvider);
            await migrationService.migrateAndPushLocalDataToCloud(cloudUser.storeId);
            await tokens.setProMigrated(true);
          } catch (migErr) {
            debugPrint('[CloudLogin] Auto-migration notice: $migErr');
          }

          try {
            await ref.read(syncCoordinatorProvider).syncCycle();
          } catch (_) {}

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🎉 Toko Cloud Berhasil Didaftarkan! Data lokal telah disinkronkan ke server.',
                ),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/staff-login');
          }
        }
      } else {
        // ──── FLOW 2: LOGIN AKUN CLOUD YANG SUDAH ADA ────
        final user = await ref.read(cloudAuthProvider.notifier).login(
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text,
            );

        // Bind authentic cloud store & user into Drift SQLite (both local and cloud cache)
        setState(() {
          _loadingStatusText = 'Memperbarui database toko lokal...';
        });
        final localDb = ref.read(localDatabaseProvider);
        final cloudDb = ref.read(cloudCacheDatabaseProvider);

        for (final db in [localDb, cloudDb]) {
          await db.storeDao.ensureStoreWithId(
            id: user.storeId,
            name: user.storeName,
            subscriptionPlan: user.tier,
            subscriptionStatus: 'ACTIVE',
          );
          await db.storeDao.bindCloudStoreAndUser(
            storeId: user.storeId,
            storeName: user.storeName,
            subscriptionPlan: user.tier,
            userId: user.userId,
            username: user.username,
            displayName: user.displayName,
          );
          await db.storeDao.healAllOrphanRecords(user.storeId);
        }
        await tokens.setStorePaired(true);

        if (user.tier == 'FREE' || !user.canCloudSync) {
          // FREE tier: Single-user Owner, auto-bypass staff login
          await tokens.saveCashierSession(
            userId: user.userId,
            username: user.username,
            displayName: user.displayName,
            role: 'OWNER',
            permissions: user.permissions,
          );
          await tokens.setCloudMode(false);
          await ref
              .read(appOperationalModeProvider.notifier)
              .switchMode(AppOperationalMode.local);
          try {
            ref.read(syncCoordinatorProvider).stopPeriodicSync();
          } catch (_) {}

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Berhasil mengaktifkan toko! Mode Lokal (FREE) aktif.'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/');
          }
        } else {
          // PRO/PAID tier: Set cloud mode, clear cashier session, migrate local data, proceed to staff login
          await tokens.setCloudMode(true);
          await ref
              .read(appOperationalModeProvider.notifier)
              .switchMode(AppOperationalMode.cloud);
          await tokens.clearCashierSession();

          // Auto-migrate local offline data (products, categories, offline transactions) to cloud
          try {
            setState(() {
              _loadingStatusText = 'Menyelaraskan data offline & transaksi ke Cloud...';
            });
            final migrationService = ref.read(dataMigrationServiceProvider);
            await migrationService.migrateAndPushLocalDataToCloud(user.storeId);
            await tokens.setProMigrated(true);
          } catch (migErr) {
            debugPrint('[CloudLogin] Auto-migration notice: $migErr');
          }

          try {
            await ref.read(syncCoordinatorProvider).syncCycle();
          } catch (_) {}

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Perangkat terhubung ke Toko Cloud! Data transaksi disinkronkan.'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/staff-login');
          }
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
          _selectedTab == 0 ? 'Daftar Toko Baru (Free)' : 'Masuk Akun Toko',
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
                      child: Icon(Icons.point_of_sale_rounded,
                          size: 38, color: cs.onPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedTab == 0 ? 'Daftar Toko Baru' : 'Masuk Akun Toko',
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
                        ? 'Daftarkan toko Anda untuk mulai menggunakan kasir offline mandiri di Android.'
                        : 'Masuk dengan kredensial pemilik atau staf toko Anda.',
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
                                'Daftar Toko (Free)',
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
                                'Masuk Akun Toko',
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
                  const SizedBox(height: 14),

                  // ──── SERVER ENDPOINT CONFIGURATION ────
                  _SectionLabel(label: 'Server Cloud (Backend API)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _serverUrlCtrl,
                    decoration: _inputDecoration(
                      context,
                      hint: 'http://localhost:5000',
                      icon: Icons.dns_outlined,
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Reset ke default sistem',
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        onPressed: () {
                          setState(() {
                            _serverUrlCtrl.text = AppConfig.defaultBaseUrl;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'URL Server wajib diisi';
                      if (!v.startsWith('http://') && !v.startsWith('https://')) {
                        return 'URL harus diawali http:// atau https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 14),
                        label: const Text('Localhost (5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _serverUrlCtrl.text = 'http://localhost:5000'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.phone_android, size: 14),
                        label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _serverUrlCtrl.text = 'http://10.0.2.2:5000'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.cloud_queue, size: 14),
                        label: const Text('Production', style: TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _serverUrlCtrl.text = 'https://pos-api.kevinsultana.online'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Free offline info notice
                  if (_selectedTab == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.offline_pin_rounded, color: AppColors.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pendaftaran otomatis mengaktifkan Paket FREE (100% Offline). Anda dapat beralih ke Cloud PRO kapan saja.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: cs.onSurface,
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
                            ? Icons.storefront_rounded
                            : Icons.login_rounded),
                    label: Text(
                      _isLoading
                          ? (_loadingStatusText ?? 'Memproses...')
                          : (_selectedTab == 0
                              ? 'Daftarkan Toko Gratis'
                              : 'Masuk ke Kasir POS'),
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
