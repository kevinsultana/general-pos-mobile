import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers/cloud_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart';

class StaffLoginPage extends ConsumerStatefulWidget {
  const StaffLoginPage({super.key});

  @override
  ConsumerState<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends ConsumerState<StaffLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;

  String _storeName = 'Memuat Toko...';
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    final tokens = ref.read(tokenStorageProvider);
    final sId = await tokens.getStoreId();
    final sName = await tokens.getStoreName();
    if (mounted) {
      setState(() {
        _storeId = sId;
        _storeName = (sName != null && sName.isNotEmpty) ? sName : 'Toko POS Cloud PRO';
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final tokens = ref.read(tokenStorageProvider);
      final pairedStoreId = await tokens.getStoreId();

      final staffUser = await ref.read(cloudAuthProvider.notifier).loginStaff(
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

      if (pairedStoreId != null &&
          pairedStoreId.isNotEmpty &&
          staffUser.storeId.isNotEmpty &&
          staffUser.storeId != pairedStoreId) {
        throw Exception('Akun staf ini tidak terdaftar di toko ini.');
      }

      // Save/update staff user in BOTH local and cloud cache Drift SQLite
      final localDb = ref.read(localDatabaseProvider);
      final cloudDb = ref.read(cloudCacheDatabaseProvider);
      final now = DateTime.now();

      for (final db in [localDb, cloudDb]) {
        await db.userDao.insertUser(
          UsersCompanion.insert(
            id: staffUser.userId,
            storeId: staffUser.storeId,
            username: staffUser.username,
            displayName: staffUser.displayName,
            passwordHash: 'CLOUD_AUTHENTICATED',
            role: drift.Value(staffUser.role.isNotEmpty ? staffUser.role : 'CASHIER'),
            active: const drift.Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Set mode to CLOUD and start background sync coordinator
      await tokens.setCloudMode(true);
      await ref
          .read(appOperationalModeProvider.notifier)
          .switchMode(AppOperationalMode.cloud);

      try {
        ref.read(syncCoordinatorProvider).startPeriodicSync();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '👋 Selamat bertugas, ${staffUser.displayName}! Kasir Cloud PRO siap.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showUnpairDialog() async {
    final passwordCtrl = TextEditingController();
    bool unpairLoading = false;
    String? unpairError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.link_off_rounded, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 8),
              const Text('Putus Perangkat?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perangkat ini saat ini terhubung ke toko $_storeName. Untuk memutuskan hubungan perangkat ini, masukkan password Owner toko:',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password Owner',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (unpairError != null) ...[
                const SizedBox(height: 8),
                Text(
                  unpairError!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: unpairLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: unpairLoading
                  ? null
                  : () async {
                      if (passwordCtrl.text.isEmpty) {
                        setDialogState(() => unpairError = 'Password wajib diisi');
                        return;
                      }
                      setDialogState(() {
                        unpairLoading = true;
                        unpairError = null;
                      });

                      try {
                        await ref
                            .read(cloudAuthProvider.notifier)
                            .unpairStore(ownerPassword: passwordCtrl.text);

                        final resetService = ref.read(dataResetServiceProvider);
                        await resetService.resetEverything();
                        await ref
                            .read(appOperationalModeProvider.notifier)
                            .switchMode(AppOperationalMode.local);

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Perangkat berhasil diputuskan dari toko.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          context.go('/cloud-login');
                        }
                      } catch (e) {
                        setDialogState(() {
                          unpairLoading = false;
                          unpairError = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: unpairLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Putus Perangkat'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store & Device Badge
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Login Staf Kasir',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Paired store info card
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: Color(0xFF6366F1), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _storeName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'TERHUBUNG (PRO)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Multi-Kasir Aktif',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Username Staf',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: _inputDecoration(
                      context,
                      hint: 'Masukkan username staf kasir',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Username staf wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Password Staf',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
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
                        (v == null || v.length < 4) ? 'Password minimal 4 karakter' : null,
                  ),
                  const SizedBox(height: 16),

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

                  FilledButton.icon(
                    onPressed: _isLoading ? null : _onLogin,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      _isLoading ? 'Memverifikasi...' : 'Mulai Shift Kasir',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: const Text(
                        'Putus Hubungan Toko (Unpair)',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _showUnpairDialog,
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
