import '../../data/local/cloud_database.dart' show SyncEvent;
import '../../data/services/cloud_sync_service.dart';

abstract class ISyncRepository {
  /// Queue a business event for syncing.
  Future<void> enqueuePush({
    required String operation,
    required String entityId,
    required Map<String, dynamic> payload,
  });

  /// Push all pending events to the server.
  Future<SyncPushResult> pushAll();

  /// Pull latest events from server since the last cursor.
  Future<int> pull();

  /// Get all failed events.
  Future<List<SyncEvent>> getFailedEvents();

  /// Retry all failed events.
  Future<SyncPushResult> retryFailed();

  /// Stream of pending event count.
  Stream<int> watchPendingCount(String storeId);
}
