import 'dart:async';
import '../../domain/repositories/i_sync_repository.dart';
import 'cloud_sync_service.dart';

/// Coordinates automatic periodic background sync and event-driven immediate push
/// operations when the app is in Cloud Mode.
class SyncCoordinator {
  final ISyncRepository _syncRepo;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _pendingPushRequested = false;

  SyncCoordinator(this._syncRepo);

  /// Start periodic sync (e.g. every 30 seconds).
  /// Safe to call multiple times (re-entrant).
  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      syncCycle();
    });
  }

  /// Stop periodic sync timer (e.g. when switching to Local Mode or disposing).
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Execute a full push & pull sync cycle safely in background.
  Future<void> syncCycle() async {
    if (_isSyncing) {
      _pendingPushRequested = true;
      return;
    }

    _isSyncing = true;
    try {
      // 1. Push all pending local events to server
      await _syncRepo.pushAll();

      // 2. Pull latest server events
      await _syncRepo.pull();
    } catch (_) {
      // Silently swallow errors during background sync — network offline/timeout
      // is expected in mobile retail environments.
    } finally {
      _isSyncing = false;
      if (_pendingPushRequested) {
        _pendingPushRequested = false;
        triggerImmediatePush();
      }
    }
  }

  /// Triggers an immediate push in the background (fire-and-forget).
  /// Called immediately after a transaction, cancellation, refund, or catalog change.
  void triggerImmediatePush() {
    if (_isSyncing) {
      _pendingPushRequested = true;
      return;
    }

    _isSyncing = true;
    unawaited(
      _syncRepo.pushAll().catchError((_) {
        return SyncPushResult.empty();
      }).whenComplete(() {
        _isSyncing = false;
        if (_pendingPushRequested) {
          _pendingPushRequested = false;
          triggerImmediatePush();
        }
      }),
    );
  }

  void dispose() {
    stopPeriodicSync();
  }
}
