import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/app_config.dart';

/// Keys used in secure storage.
class _StorageKeys {
  static const accessToken = 'cloud_access_token';
  static const refreshToken = 'cloud_refresh_token';
  static const serverUrl = 'cloud_server_url';
  static const storeId = 'cloud_store_id';
  static const deviceId = 'cloud_device_id';
  static const userId = 'cloud_user_id';
  static const isCloudMode = 'cloud_mode_enabled';
  static const permissions = 'cloud_permissions';
  static const username = 'cloud_username';
  static const displayName = 'cloud_display_name';
  static const storeName = 'cloud_store_name';
  static const isProMigrated = 'cloud_pro_migrated';
}

/// Manages JWT tokens, cloud server URL, and cached user profile/permissions in secure storage.
class TokenStorage {
  final FlutterSecureStorage _storage;

  const TokenStorage(this._storage);

  Future<String?> getAccessToken() => _storage.read(key: _StorageKeys.accessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _StorageKeys.refreshToken);
  Future<String?> getServerUrl() => _storage.read(key: _StorageKeys.serverUrl);
  Future<String?> getStoreId() => _storage.read(key: _StorageKeys.storeId);
  Future<String?> getDeviceId() => _storage.read(key: _StorageKeys.deviceId);
  Future<String?> getUserId() => _storage.read(key: _StorageKeys.userId);
  Future<String?> getUsername() => _storage.read(key: _StorageKeys.username);
  Future<String?> getDisplayName() => _storage.read(key: _StorageKeys.displayName);
  Future<String?> getStoreName() => _storage.read(key: _StorageKeys.storeName);

  Future<List<String>> getPermissions() async {
    final val = await _storage.read(key: _StorageKeys.permissions);
    if (val == null || val.isEmpty) return [];
    try {
      final list = jsonDecode(val) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isCloudMode() async {
    final val = await _storage.read(key: _StorageKeys.isCloudMode);
    return val == 'true';
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String storeId,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _StorageKeys.accessToken, value: accessToken),
      _storage.write(key: _StorageKeys.refreshToken, value: refreshToken),
      _storage.write(key: _StorageKeys.storeId, value: storeId),
      _storage.write(key: _StorageKeys.userId, value: userId),
    ]);
  }

  Future<void> saveUserData({
    required String username,
    required String displayName,
    required String storeName,
    required List<String> permissions,
  }) async {
    await Future.wait([
      _storage.write(key: _StorageKeys.username, value: username),
      _storage.write(key: _StorageKeys.displayName, value: displayName),
      _storage.write(key: _StorageKeys.storeName, value: storeName),
      _storage.write(key: _StorageKeys.permissions, value: jsonEncode(permissions)),
    ]);
  }

  Future<void> saveServerConfig({required String serverUrl, required String deviceId}) async {
    await Future.wait([
      _storage.write(key: _StorageKeys.serverUrl, value: serverUrl),
      _storage.write(key: _StorageKeys.deviceId, value: deviceId),
    ]);
  }

  Future<void> setCloudMode(bool enabled) =>
      _storage.write(key: _StorageKeys.isCloudMode, value: enabled.toString());

  Future<bool> isProMigrated() async {
    final val = await _storage.read(key: _StorageKeys.isProMigrated);
    return val == 'true';
  }

  Future<void> setProMigrated(bool migrated) =>
      _storage.write(key: _StorageKeys.isProMigrated, value: migrated.toString());

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _StorageKeys.accessToken),
      _storage.delete(key: _StorageKeys.refreshToken),
      _storage.delete(key: _StorageKeys.storeId),
      _storage.delete(key: _StorageKeys.userId),
      _storage.delete(key: _StorageKeys.permissions),
      _storage.delete(key: _StorageKeys.username),
      _storage.delete(key: _StorageKeys.displayName),
      _storage.delete(key: _StorageKeys.storeName),
    ]);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

/// Dio-based HTTP client for the Cloud POS backend.
/// Automatically attaches Bearer token and handles 401 by refreshing.
class ApiClient {
  final TokenStorage _tokenStorage;
  late final Dio _dio;

  ApiClient(this._tokenStorage) {
    _dio = Dio();
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    _dio.options.headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final deviceId = await _tokenStorage.getDeviceId();
        if (deviceId != null) {
          options.headers['X-Device-Id'] = deviceId;
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _tryRefresh();
          if (refreshed) {
            // Retry the original request
            try {
              final token = await _tokenStorage.getAccessToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  Completer<bool>? _refreshCompleter;

  Future<bool> _tryRefresh() async {
    // If a refresh is already in flight, await the same single future to avoid concurrent refresh token rotation conflicts
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final savedUrl = await _tokenStorage.getServerUrl();
      final serverUrl = AppConfig.normalizeUrl(
        (savedUrl != null && savedUrl.isNotEmpty) ? savedUrl : AppConfig.defaultBaseUrl,
      );
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await Dio().post(
        '$serverUrl/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data['data'];
      final storeId = await _tokenStorage.getStoreId();
      final userId = await _tokenStorage.getUserId();
      await _tokenStorage.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        storeId: storeId ?? '',
        userId: userId ?? '',
      );
      _refreshCompleter!.complete(true);
      return true;
    } on DioException catch (dioErr) {
      // Only clear tokens if the server explicitly rejected the refresh token (HTTP 401 or 403).
      // Transient network errors, socket timeouts, or offline disconnections must NOT wipe local user session!
      final status = dioErr.response?.statusCode;
      if (status == 401 || status == 403) {
        await _tokenStorage.clearTokens();
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<String> _baseUrl() async {
    final savedUrl = await _tokenStorage.getServerUrl();
    final url = (savedUrl != null && savedUrl.isNotEmpty)
        ? savedUrl
        : AppConfig.defaultBaseUrl;
    return AppConfig.normalizeUrl(url);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final base = await _baseUrl();
      final response = await _dio.post('$base$path', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _checkSubscriptionError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final base = await _baseUrl();
      final response = await _dio.get('$base$path', queryParameters: queryParams);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _checkSubscriptionError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    try {
      final base = await _baseUrl();
      final response = await _dio.put('$base$path', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _checkSubscriptionError(e);
      rethrow;
    }
  }

  void _checkSubscriptionError(DioException e) {
    if (e.response?.statusCode == 403) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'] as Map<String, dynamic>?;
        final code = err?['code'] as String?;
        final msg = err?['message'] as String? ?? 'Akses fitur ditolak';
        if (code == 'UPGRADE_REQUIRED' || code == 'SUBSCRIPTION_EXPIRED') {
          throw SubscriptionRequiredException(
            msg,
            code: code ?? 'UPGRADE_REQUIRED',
            requiredPlan: (err?['details'] as Map<String, dynamic>?)?['requiredPlan'] as String?,
          );
        }
      }
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final base = await _baseUrl();
      final response = await Dio().get(
        '$base/api/v1/health',
        options: Options(sendTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class SubscriptionRequiredException implements Exception {
  final String message;
  final String code;
  final String? requiredPlan;

  const SubscriptionRequiredException(
    this.message, {
    this.code = 'UPGRADE_REQUIRED',
    this.requiredPlan,
  });

  @override
  String toString() => message;
}

