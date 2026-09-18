import 'package:dio/dio.dart';
import 'api_client.dart';

class CloudUser {
  final String userId;
  final String username;
  final String displayName;
  final String storeId;
  final String storeName;
  final List<String> permissions;

  const CloudUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.storeId,
    required this.storeName,
    required this.permissions,
  });

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final store = json['store'] as Map<String, dynamic>? ?? {};
    final perms = (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [];

    return CloudUser(
      userId: user['id'] as String,
      username: user['username'] as String,
      displayName: user['displayName'] as String? ?? user['username'],
      storeId: store['id'] as String? ?? '',
      storeName: store['name'] as String? ?? '',
      permissions: perms,
    );
  }
}

/// Handles cloud authentication: login, logout, token persistence.
class CloudAuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  const CloudAuthService(this._apiClient, this._tokenStorage);

  /// Login to the cloud backend and persist tokens.
  Future<CloudUser> login({
    required String username,
    required String password,
    String? storeId,
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
        'password': password,
        if (storeId != null) 'storeId': storeId,
      };

      final response = await _apiClient.post('/api/v1/auth/login', body);
      final data = response['data'] as Map<String, dynamic>;

      final user = CloudUser.fromJson(data);

      await _tokenStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        storeId: user.storeId,
        userId: user.userId,
      );
      await _tokenStorage.saveUserData(
        username: user.username,
        displayName: user.displayName,
        storeName: user.storeName,
        permissions: user.permissions,
      );
      await _tokenStorage.setCloudMode(true);

      return user;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal terhubung ke server';
      throw Exception(msg);
    }
  }

  /// Register a new cloud store (PRO plan) and persist tokens.
  Future<CloudUser> registerStore({
    required String storeName,
    required String username,
    required String password,
    String? ownerName,
    String? email,
    String? phone,
    String? address,
  }) async {
    try {
      final body = <String, dynamic>{
        'storeName': storeName,
        'username': username,
        'password': password,
        if (ownerName != null && ownerName.isNotEmpty) 'ownerName': ownerName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
      };

      final response = await _apiClient.post('/api/v1/auth/register-store', body);
      final data = response['data'] as Map<String, dynamic>;

      final user = CloudUser.fromJson(data);

      await _tokenStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        storeId: user.storeId,
        userId: user.userId,
      );
      await _tokenStorage.saveUserData(
        username: user.username,
        displayName: user.displayName,
        storeName: user.storeName,
        permissions: user.permissions,
      );
      await _tokenStorage.setCloudMode(true);

      return user;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal mendaftarkan toko ke cloud';
      throw Exception(msg);
    }
  }

  /// Logout and clear tokens.
  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout', {});
    } catch (_) {
      // Best-effort
    }
    await _tokenStorage.clearTokens();
    await _tokenStorage.setCloudMode(false);
  }

  /// Check if user is currently logged into cloud.
  Future<bool> isLoggedIn() async {
    final token = await _tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current stored user info (from tokens, not re-fetching).
  Future<Map<String, String?>> getStoredInfo() async {
    return {
      'storeId': await _tokenStorage.getStoreId(),
      'userId': await _tokenStorage.getUserId(),
      'deviceId': await _tokenStorage.getDeviceId(),
    };
  }
}
