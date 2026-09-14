import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../data/services/cloud_sync_service.dart';
import '../../../data/services/api_client.dart';

/// Cloud Sync management page — shows connection status, pending events,
/// allows manual sync trigger, and shows failed events with retry option.
class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});

  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage> {
  SyncPushResult? _lastResult;
  String? _lastError;
  DateTime? _lastSyncTime;
  bool _isChecking = false;
  bool? _isServerOnline;
  String? _subscriptionPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    setState(() => _isChecking = true);
    final apiClient = ref.read(apiClientProvider);
    final online = await apiClient.checkConnectivity();
    String? plan;
    if (online) {
      try {
        final res = await apiClient.get('/api/v1/subscription');
        final data = res['data'] as Map<String, dynamic>?;
        plan = data?['plan'] as String?;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isServerOnline = online;
        _subscriptionPlan = plan;
        _isChecking = false;
      });
    }
  }

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 48),
        title: Text('Upgrade Paket Diperlukan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          message.isNotEmpty
              ? message
              : 'Fitur sinkronisasi multi-device cloud memerlukan paket langganan minimal PAID atau PRO. Silakan hubungi admin atau buka Web Dashboard untuk meng-upgrade toko Anda.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _doSync() async {
    final statusNotifier = ref.read(syncStatusProvider.notifier);
    statusNotifier.setSyncing();
    setState(() => _lastError = null);

    try {
      final syncRepo = ref.read(syncRepositoryProvider);
      final result = await syncRepo.pushAll();
      await syncRepo.pull();
      if (mounted) {
        setState(() {
          _lastResult = result;
          _lastSyncTime = DateTime.now();
        });
        statusNotifier.setSuccess();
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceFirst('Exception: ', '');
        setState(() => _lastError = errStr);
        statusNotifier.setError();
        if (e is SubscriptionRequiredException ||
            errStr.contains('UPGRADE_REQUIRED') ||
            errStr.contains('SUBSCRIPTION_EXPIRED')) {
          _showUpgradeDialog(errStr);
        }
      }
    }
  }

  Future<void> _retryFailed() async {
    final syncRepo = ref.read(syncRepositoryProvider);
    final result = await syncRepo.retryFailed();
    if (mounted) {
      setState(() {
        _lastResult = result;
        _lastSyncTime = DateTime.now();
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Cloud?'),
        content: const Text(
            'Token akan dihapus dan mode Cloud akan dinonaktifkan. Event yang belum tersinkronisasi akan tetap tersimpan secara lokal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(cloudAuthProvider.notifier).logout();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cloud Sync', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _checkConnection),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Keluar dari Cloud',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Operational Mode Switcher ──
          const _OperationalModeCard(),
          const SizedBox(height: 12),

          // ── Subscription Plan Badge ──
          if (_subscriptionPlan != null) ...[
            _SubscriptionBadgeCard(plan: _subscriptionPlan!),
            const SizedBox(height: 12),
          ],

          // ── Connection Status ──
          _StatusCard(
            isChecking: _isChecking,
            isOnline: _isServerOnline,
            onRefresh: _checkConnection,
          ),
          const SizedBox(height: 12),

          // ── Sync Status ──
          _SyncStatusCard(
            syncStatus: syncStatus,
            lastResult: _lastResult,
            lastSyncTime: _lastSyncTime,
            lastError: _lastError,
          ),
          const SizedBox(height: 12),

          // ── Pending Events Counter ──
          _PendingCountCard(),
          const SizedBox(height: 12),

          // ── Sync Actions ──
          _SyncActionsCard(
            syncStatus: syncStatus,
            onSyncNow: _doSync,
            onRetryFailed: _retryFailed,
          ),
          const SizedBox(height: 12),

          // ── Info ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.secondaryContainer),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, color: cs.secondary, size: 18),
                  const SizedBox(width: 8),
                  Text('Cara Kerja Sync', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: cs.secondary)),
                ]),
                const SizedBox(height: 8),
                _InfoItem('Push', 'Kirim transaksi lokal ke server cloud'),
                _InfoItem('Pull', 'Ambil update dari device lain'),
                _InfoItem('Offline', 'Transaksi tetap berjalan, sync saat online'),
                _InfoItem('Idempoten', 'Tidak ada duplikasi meski dikirim berulang'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isChecking;
  final bool? isOnline;
  final VoidCallback onRefresh;

  const _StatusCard({required this.isChecking, required this.isOnline, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (isChecking) {
      bgColor = cs.surfaceContainerHighest;
      textColor = cs.onSurfaceVariant;
      icon = Icons.wifi_find_rounded;
      label = 'Memeriksa koneksi...';
    } else if (isOnline == true) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      icon = Icons.cloud_done_rounded;
      label = 'Server online & terhubung';
    } else if (isOnline == false) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      icon = Icons.cloud_off_rounded;
      label = 'Server tidak dapat dijangkau';
    } else {
      bgColor = cs.surfaceContainerHighest;
      textColor = cs.onSurfaceVariant;
      icon = Icons.cloud_queue_rounded;
      label = 'Status tidak diketahui';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          isChecking
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
              : Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600))),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor, size: 20),
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  final SyncStatus syncStatus;
  final SyncPushResult? lastResult;
  final DateTime? lastSyncTime;
  final String? lastError;

  const _SyncStatusCard({
    required this.syncStatus,
    required this.lastResult,
    required this.lastSyncTime,
    required this.lastError,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sync Terakhir', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (syncStatus == SyncStatus.syncing)
            Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
              const SizedBox(width: 10),
              Text('Menyinkronisasi...', style: GoogleFonts.inter(color: cs.primary, fontWeight: FontWeight.w600)),
            ])
          else if (lastError != null)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(lastError!, style: GoogleFonts.inter(color: cs.error, fontSize: 13))),
            ])
          else if (lastResult != null && lastSyncTime != null) ...[
            Text(
              DateFormat('dd MMM yyyy, HH:mm').format(lastSyncTime!),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '✅ ${lastResult!.synced} berhasil  •  ❌ ${lastResult!.failed} gagal  •  ⏭ ${lastResult!.skipped} dilewati',
              style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ] else
            Text('Belum pernah sync', style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PendingCountCard extends ConsumerWidget {
  const _PendingCountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tokenStorage = ref.watch(tokenStorageProvider);

    return FutureBuilder<String?>(
      future: tokenStorage.getStoreId(),
      builder: (context, snapshot) {
        final storeId = snapshot.data ?? '';
        if (storeId.isEmpty) return const SizedBox.shrink();

        return ref.watch(pendingCountProvider(storeId)).when(
          data: (count) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: count > 0 ? cs.primaryContainer.withValues(alpha: 0.4) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: count > 0 ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: count > 0 ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$count',
                      style: GoogleFonts.inter(
                        color: count > 0 ? cs.onPrimary : cs.onSurfaceVariant,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Event Menunggu Sync',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(count > 0 ? 'Tekan "Sync Sekarang" untuk mengirim' : 'Semua event telah tersinkronisasi',
                      style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ],
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _SyncActionsCard extends StatelessWidget {
  final SyncStatus syncStatus;
  final VoidCallback onSyncNow;
  final VoidCallback onRetryFailed;

  const _SyncActionsCard({
    required this.syncStatus,
    required this.onSyncNow,
    required this.onRetryFailed,
  });

  @override
  Widget build(BuildContext context) {
    final isSyncing = syncStatus == SyncStatus.syncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isSyncing ? null : onSyncNow,
          icon: isSyncing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync_rounded),
          label: Text(
            isSyncing ? 'Menyinkronisasi...' : 'Sync Sekarang',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isSyncing ? null : onRetryFailed,
          icon: const Icon(Icons.replay_rounded),
          label: Text('Coba Ulang Event Gagal', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String title;
  final String desc;
  const _InfoItem(this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: desc, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _OperationalModeCard extends ConsumerWidget {
  const _OperationalModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final modeAsync = ref.watch(appOperationalModeProvider);
    final mode = modeAsync.valueOrNull ?? AppOperationalMode.local;
    final isCloud = mode == AppOperationalMode.cloud;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCloud
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCloud ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCloud ? Icons.cloud_done_rounded : Icons.offline_pin_rounded,
                    color: isCloud ? cs.primary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mode Operasional Aktif',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isCloud ? cs.primary : cs.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCloud ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCloud ? 'CLOUD PRO' : 'LOKAL OFFLINE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCloud ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCloud
                ? 'Menggunakan database terisolasi "cloud_cache.sqlite". Transaksi akan disinkronkan ke server backend.'
                : 'Menggunakan database terisolasi "local.sqlite". Beroperasi standalone tanpa sinkronisasi cloud.',
            style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppOperationalMode>(
              segments: const [
                ButtonSegment(
                  value: AppOperationalMode.local,
                  icon: Icon(Icons.storage_rounded, size: 16),
                  label: Text('Mode Lokal'),
                ),
                ButtonSegment(
                  value: AppOperationalMode.cloud,
                  icon: Icon(Icons.cloud_sync_rounded, size: 16),
                  label: Text('Mode Cloud'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selected) async {
                final target = selected.first;
                if (target == mode) return;

                if (target == AppOperationalMode.local) {
                  // Check if there are pending events in cloud cache
                  final tokens = ref.read(tokenStorageProvider);
                  final storeId = await tokens.getStoreId();
                  int pending = 0;
                  if (storeId != null) {
                    final dao = ref.read(syncEventDaoProvider);
                    final pendingList = await dao.getPendingEvents(storeId);
                    pending = pendingList.length;
                  }

                  if (pending > 0 && context.mounted) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Peringatan Peralihan Mode'),
                        content: Text(
                          'Terdapat $pending transaksi di Cloud Cache yang belum tersinkronisasi ke server.\n\n'
                          'Jika Anda beralih ke Mode Lokal sekarang, transaksi tersebut akan tetap tersimpan di Cloud Cache dan baru akan dikirimkan saat Anda beralih kembali ke Mode Cloud.\n\n'
                          'Tetap beralih ke Mode Lokal?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Ya, Beralih ke Lokal'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }
                  await ref.read(appOperationalModeProvider.notifier).switchMode(AppOperationalMode.local);
                } else {
                  // Switching to Cloud: verify login
                  final tokens = ref.read(tokenStorageProvider);
                  final token = await tokens.getAccessToken();
                  if (token == null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silakan login terlebih dahulu untuk mengaktifkan Mode Cloud.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  await ref.read(appOperationalModeProvider.notifier).switchMode(AppOperationalMode.cloud);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBadgeCard extends StatelessWidget {
  final String plan;
  const _SubscriptionBadgeCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPro = plan == 'PRO';
    final isPaid = plan == 'PAID';
    final badgeColor = isPro
        ? Colors.amber.shade700
        : (isPaid ? Colors.blue.shade600 : Colors.grey.shade600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isPro
                ? Icons.workspace_premium_rounded
                : (isPaid ? Icons.cloud_done_rounded : Icons.lock_outline_rounded),
            color: badgeColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Paket Langganan: ', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        plan,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isPro
                      ? 'Akses penuh: Mobile Cloud + Web Dashboard Pro'
                      : (isPaid
                          ? 'Akses Cloud multi-device aktif'
                          : 'Paket Gratis: Hanya POS offline lokal. Upgrade untuk Cloud Sync.'),
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
