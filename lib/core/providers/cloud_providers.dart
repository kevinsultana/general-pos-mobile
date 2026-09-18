import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/cloud_database.dart';
import '../../data/services/api_client.dart';
import '../../data/services/cloud_auth_service.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../data/services/sync_coordinator.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/repositories/i_sync_repository.dart';
import '../../data/services/data_migration_service.dart';
import '../../data/services/data_reset_service.dart';
import 'database_providers.dart' show cloudCacheDatabaseProvider, localDatabaseProvider;


// ──────────────── Storage & HTTP Client ────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return TokenStorage(storage);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  return ApiClient(tokens);
});

// ──────────────── Cloud Database ────────────────

final cloudDatabaseProvider = Provider<CloudDatabase>((ref) {
  final db = CloudDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ──────────────── Auth ────────────────

final cloudAuthServiceProvider = Provider<CloudAuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokens = ref.watch(tokenStorageProvider);
  return CloudAuthService(apiClient, tokens);
});

/// Notifier that holds the current cloud auth state.
class CloudAuthNotifier extends AsyncNotifier<CloudUser?> {
  @override
  Future<CloudUser?> build() async {
    final authService = ref.watch(cloudAuthServiceProvider);
    final isLoggedIn = await authService.isLoggedIn();
    if (!isLoggedIn) return null;

    final tokens = ref.watch(tokenStorageProvider);
    final storeId = await tokens.getStoreId();
    final userId = await tokens.getUserId();
    if (storeId == null || userId == null) return null;

    final username = await tokens.getUsername() ?? 'user';
    final displayName = await tokens.getDisplayName() ?? username;
    final storeName = await tokens.getStoreName() ?? '';
    final perms = await tokens.getPermissions();

    return CloudUser(
      userId: userId,
      username: username,
      displayName: displayName,
      storeId: storeId,
      storeName: storeName,
      permissions: perms,
    );
  }

  Future<CloudUser> login({
    required String username,
    required String password,
    String? storeId,
  }) async {
    state = const AsyncLoading();
    final authService = ref.read(cloudAuthServiceProvider);
    try {
      final user = await authService.login(
        username: username,
        password: password,
        storeId: storeId,
      );
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<CloudUser> registerStore({
    required String storeName,
    required String username,
    required String password,
    String? ownerName,
    String? email,
    String? phone,
    String? address,
  }) async {
    state = const AsyncLoading();
    final authService = ref.read(cloudAuthServiceProvider);
    try {
      final user = await authService.registerStore(
        storeName: storeName,
        username: username,
        password: password,
        ownerName: ownerName,
        email: email,
        phone: phone,
        address: address,
      );
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    final authService = ref.read(cloudAuthServiceProvider);
    await authService.logout();
    state = const AsyncData(null);
  }
}

final cloudAuthProvider = AsyncNotifierProvider<CloudAuthNotifier, CloudUser?>(() {
  return CloudAuthNotifier();
});

final isProMigratedProvider = FutureProvider<bool>((ref) async {
  final tokens = ref.watch(tokenStorageProvider);
  return tokens.isProMigrated();
});

final dataResetServiceProvider = Provider<DataResetService>((ref) {
  final localDb = ref.watch(localDatabaseProvider);
  final cloudDb = ref.watch(cloudCacheDatabaseProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return DataResetService(
    localDb: localDb,
    cloudDb: cloudDb,
    tokenStorage: tokenStorage,
  );
});

final dataMigrationServiceProvider = Provider<DataMigrationService>((ref) {
  final localDb = ref.watch(localDatabaseProvider);
  final cloudDb = ref.watch(cloudCacheDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return DataMigrationService(
    localDb: localDb,
    cloudDb: cloudDb,
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );
});

/// Operational Mode: LOCAL (standalone offline) or CLOUD (multi-device sync)
enum AppOperationalMode {
  local,
  cloud,
}

class AppOperationalModeNotifier extends AsyncNotifier<AppOperationalMode> {
  @override
  Future<AppOperationalMode> build() async {
    final tokens = ref.watch(tokenStorageProvider);
    final isCloud = await tokens.isCloudMode();
    return isCloud ? AppOperationalMode.cloud : AppOperationalMode.local;
  }

  Future<void> switchMode(AppOperationalMode newMode) async {
    state = const AsyncLoading();
    final tokens = ref.read(tokenStorageProvider);
    await tokens.setCloudMode(newMode == AppOperationalMode.cloud);
    state = AsyncData(newMode);
  }
}

final appOperationalModeProvider =
    AsyncNotifierProvider<AppOperationalModeNotifier, AppOperationalMode>(() {
  return AppOperationalModeNotifier();
});

final isCloudModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(appOperationalModeProvider).valueOrNull;
  return mode == AppOperationalMode.cloud;
});

// ──────────────── Sync ────────────────

final syncEventDaoProvider = Provider<dynamic>((ref) {
  final db = ref.watch(cloudCacheDatabaseProvider);
  return db.syncEventDao;
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final dao = ref.watch(syncEventDaoProvider);
  final apiClient = ref.watch(apiClientProvider);
  final tokens = ref.watch(tokenStorageProvider);
  final db = ref.watch(cloudCacheDatabaseProvider);
  return CloudSyncService(dao, apiClient, tokens, db);
});

final syncRepositoryProvider = Provider<ISyncRepository>((ref) {
  final syncService = ref.watch(cloudSyncServiceProvider);
  final tokens = ref.watch(tokenStorageProvider);
  return SyncRepositoryImpl(syncService, tokens);
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final coordinator = SyncCoordinator(syncRepo);
  final isCloud = ref.watch(isCloudModeProvider);

  if (isCloud) {
    coordinator.startPeriodicSync();
  } else {
    coordinator.stopPeriodicSync();
  }

  ref.onDispose(() => coordinator.dispose());
  return coordinator;
});

// ──────────────── Sync Status ────────────────

enum SyncStatus { idle, syncing, error, success }

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(SyncStatus.idle);

  void setSyncing() => state = SyncStatus.syncing;
  void setSuccess() => state = SyncStatus.success;
  void setError() => state = SyncStatus.error;
  void setIdle() => state = SyncStatus.idle;
}

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

final pendingCountProvider = StreamProvider.family<int, String>((ref, storeId) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchPendingCount(storeId);
});

/// Provider that auto-generates a unique device ID on first use.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final tokens = ref.watch(tokenStorageProvider);
  var deviceId = await tokens.getDeviceId();
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = const Uuid().v4();
    await tokens.saveServerConfig(
      serverUrl: await tokens.getServerUrl() ?? '',
      deviceId: deviceId,
    );
  }
  return deviceId;
});
