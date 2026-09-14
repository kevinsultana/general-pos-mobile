import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/cloud_providers.dart';

/// Login page for cloud backend access.
/// Allows user to set server URL and login with credentials.
class CloudLoginPage extends ConsumerStatefulWidget {
  const CloudLoginPage({super.key});

  @override
  ConsumerState<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends ConsumerState<CloudLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlCtrl = TextEditingController(text: 'http://');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final tokens = ref.read(tokenStorageProvider);
    final savedUrl = await tokens.getServerUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _serverUrlCtrl.text = savedUrl;
    }
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
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
      // Save server URL first
      final tokens = ref.read(tokenStorageProvider);
      final deviceId = await ref.read(deviceIdProvider.future);
      await tokens.saveServerConfig(
        serverUrl: _serverUrlCtrl.text.trim(),
        deviceId: deviceId,
      );

      await ref.read(cloudAuthProvider.notifier).login(
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

      // Explicitly activate cloud mode
      await tokens.setCloudMode(true);
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
          'Masuk ke Cloud POS',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cloud icon header
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(Icons.cloud_sync_rounded,
                          size: 44, color: cs.onPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sinkronisasi Cloud',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hubungkan ke server backend untuk mengaktifkan sinkronisasi multi-device.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Server URL
                  _SectionLabel(label: 'URL Server'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _serverUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      context,
                      hint: 'http://192.168.1.100:5000',
                      icon: Icons.dns_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'URL server wajib diisi';
                      if (!v.startsWith('http://') && !v.startsWith('https://')) {
                        return 'URL harus diawali http:// atau https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Username
                  _SectionLabel(label: 'Username'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: _inputDecoration(
                      context,
                      hint: 'admin',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Username wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  _SectionLabel(label: 'Password'),
                  const SizedBox(height: 8),
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
                        (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                  ),
                  const SizedBox(height: 24),

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

                  // Login Button
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _onLogin,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      _isLoading ? 'Menghubungkan...' : 'Masuk',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 16),
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
