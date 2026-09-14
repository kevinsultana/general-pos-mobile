import '../../data/local/cloud_database.dart' show SyncEvent;
import '../../data/services/cloud_sync_service.dart';
import '../../data/services/api_client.dart';
import '../../domain/repositories/i_sync_repository.dart';

class SyncRepositoryImpl implements ISyncRepository {
  final CloudSyncService _syncService;
  final TokenStorage _tokenStorage;

  const SyncRepositoryImpl(this._syncService, this._tokenStorage);

  @override
  Future<void> enqueuePush({
    required String operation,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final storeId = await _tokenStorage.getStoreId();
    final deviceId = await _tokenStorage.getDeviceId();
    if (storeId == null || deviceId == null) return;

    await _syncService.enqueueEvent(
      storeId: storeId,
      deviceId: deviceId,
      operation: operation,
      entityId: entityId,
      payload: payload,
    );
  }

  @override
  Future<SyncPushResult> pushAll() => _syncService.pushPendingEvents();

  @override
  Future<int> pull() => _syncService.pullLatestEvents();

  @override
  Future<List<SyncEvent>> getFailedEvents() async {
    final storeId = await _tokenStorage.getStoreId();
    if (storeId == null) return [];
    return _syncService.getFailedEvents(storeId);
  }

  @override
  Future<SyncPushResult> retryFailed() => _syncService.retryFailed();

  @override
  Stream<int> watchPendingCount(String storeId) =>
      _syncService.watchPendingCount(storeId);
}
