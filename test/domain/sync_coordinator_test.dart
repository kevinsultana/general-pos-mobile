import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/services/cloud_sync_service.dart';
import 'package:mobile_pos/data/services/sync_coordinator.dart';
import 'package:mobile_pos/domain/repositories/i_sync_repository.dart';
import 'package:mobile_pos/data/local/cloud_database.dart';

class MockSyncRepository implements ISyncRepository {
  int pushCount = 0;
  int pullCount = 0;
  Completer<SyncPushResult>? pushCompleter;

  @override
  Future<SyncPushResult> pushAll() async {
    pushCount++;
    if (pushCompleter != null) {
      return pushCompleter!.future;
    }
    return SyncPushResult.empty();
  }

  @override
  Future<int> pull() async {
    pullCount++;
    return 0;
  }

  @override
  Future<void> enqueuePush({
    required String operation,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<List<SyncEvent>> getConflictEvents() async => [];

  @override
  Future<List<SyncEvent>> getFailedEvents() async => [];

  @override
  Future<SyncPushResult> retryConflicts() async => SyncPushResult.empty();

  @override
  Future<SyncPushResult> retryFailed() async => SyncPushResult.empty();

  @override
  Stream<int> watchPendingCount(String storeId) => Stream.value(0);
}

void main() {
  group('SyncCoordinator Tests (Phase 3)', () {
    late MockSyncRepository mockRepo;
    late SyncCoordinator coordinator;

    setUp(() {
      mockRepo = MockSyncRepository();
      coordinator = SyncCoordinator(mockRepo);
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('triggerImmediatePush triggers pushAll on sync repo', () async {
      expect(mockRepo.pushCount, equals(0));

      coordinator.triggerImmediatePush();

      // Allow microtasks to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.pushCount, equals(1));
    });

    test('syncCycle executes pushAll and pull sequentially', () async {
      await coordinator.syncCycle();

      expect(mockRepo.pushCount, equals(1));
      expect(mockRepo.pullCount, equals(1));
    });

    test('startPeriodicSync executes cycles periodically and stopPeriodicSync halts it', () async {
      coordinator.startPeriodicSync(interval: const Duration(milliseconds: 100));

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(mockRepo.pushCount, greaterThanOrEqualTo(2));

      coordinator.stopPeriodicSync();
      final countAfterStop = mockRepo.pushCount;

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(mockRepo.pushCount, equals(countAfterStop));
    });

    test('coalesces concurrent pushes when a push is already in-flight', () async {
      mockRepo.pushCompleter = Completer<SyncPushResult>();

      // First push starts
      coordinator.triggerImmediatePush();
      expect(mockRepo.pushCount, equals(1));

      // Second and third pushes while first is still in-flight
      coordinator.triggerImmediatePush();
      coordinator.triggerImmediatePush();
      expect(mockRepo.pushCount, equals(1)); // Not invoked yet

      // Complete the in-flight push
      mockRepo.pushCompleter!.complete(SyncPushResult.empty());
      mockRepo.pushCompleter = null;

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The queued push executes once (coalesced)
      expect(mockRepo.pushCount, equals(2));
    });
  });
}
