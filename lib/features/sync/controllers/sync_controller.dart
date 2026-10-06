import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tenant_model.dart';
import '../services/sync_service.dart';

class SyncController with ChangeNotifier {
  final SyncService _syncService = SyncService();

  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastSyncTime;
  String? _errorMessage;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  Future<void> checkPendingSyncCount(String tenantId) async {
    _pendingCount = await _syncService.getPendingCount(tenantId);
    notifyListeners();
  }

  Future<bool> performSync(BuildContext context, TenantModel tenant) async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    final success = await _syncService.executeSync(tenant);

    _isSyncing = false;
    if (success) {
      _lastSyncTime = DateFormat('HH:mm:ss').format(DateTime.now());
      _pendingCount = await _syncService.getPendingCount(tenant.id);
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sinkronisasi cloud berhasil diselesaikan!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } else {
      _errorMessage = 'Gagal sinkronisasi. Periksa koneksi internet ke server.';
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<void> syncIfUpgraded(BuildContext context, TenantModel tenant) async {
    if (tenant.isProOrPlus) {
      await performSync(context, tenant);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun masih berada di Free Plan (Penyimpanan SQLite Lokal).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
