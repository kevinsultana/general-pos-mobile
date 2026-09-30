import 'package:dio/dio.dart';
import 'api_client.dart';

class CloudUser {
  final String userId;
  final String username;
  final String displayName;
  final String storeId;
  final String storeName;
  final String tier;
  final bool canCloudSync;
  final List<String> permissions;
  final String role;

  const CloudUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.storeId,
    required this.storeName,
    this.tier = 'FREE',
    this.canCloudSync = false,
    required this.permissions,
    this.role = 'CASHIER',
  });

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? {};
    final store = (json['store'] as Map<String, dynamic>?) ?? {};
    final perms = (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
    final tier = (user['tier'] ?? store['subscriptionPlan'] ?? store['plan'] ?? 'FREE')
        .toString()
        .toUpperCase();
    final canCloudSync = user['canCloudSync'] == true || tier == 'PRO' || tier == 'PAID';
    final role = (user['role'] is Map<String, dynamic>)
        ? (user['role']['name'] ?? 'CASHIER').toString()
        : (user['role'] ?? 'CASHIER').toString();

    return CloudUser(
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      displayName: user['displayName'] as String? ?? user['username'] as String? ?? '',
      storeId: store['id'] as String? ?? user['storeId'] as String? ?? '',
      storeName: store['name'] as String? ?? user['storeName'] as String? ?? '',
      tier: tier,
      canCloudSync: canCloudSync,
      permissions: perms,
      role: role,
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
      await _tokenStorage.saveTier(
        tier: user.tier,
        canCloudSync: user.canCloudSync,
      );
      await _tokenStorage.setCloudMode(user.tier == 'PRO' || user.tier == 'PAID' || user.canCloudSync);

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
      await _tokenStorage.saveTier(
        tier: user.tier,
        canCloudSync: user.canCloudSync,
      );
      await _tokenStorage.setCloudMode(user.tier == 'PRO' || user.tier == 'PAID' || user.canCloudSync);

      return user;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal mendaftarkan toko ke cloud';
      throw Exception(msg);
    }
  }

  /// Login as a store staff member on a paired device.
  Future<CloudUser> loginStaff({
    required String username,
    required String password,
  }) async {
    try {
      final storeId = await _tokenStorage.getStoreId();
      if (storeId == null || storeId.isEmpty) {
        throw Exception('Perangkat belum dipasangkan ke toko');
      }

      final body = <String, dynamic>{
        'username': username,
        'password': password,
        'storeId': storeId,
      };

      final response = await _apiClient.post('/api/v1/auth/login', body);
      final data = response['data'] as Map<String, dynamic>;
      final user = CloudUser.fromJson(data);

      if (user.storeId.isNotEmpty && user.storeId != storeId) {
        throw Exception('Akun staf ini tidak terdaftar di toko ini.');
      }

      if (data['accessToken'] != null) {
        await _tokenStorage.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: (data['refreshToken'] ?? '') as String,
          storeId: storeId,
          userId: user.userId,
        );
      }

      await _tokenStorage.saveCashierSession(
        userId: user.userId,
        username: user.username,
        displayName: user.displayName,
        role: user.role.isNotEmpty ? user.role : 'CASHIER',
        permissions: user.permissions,
      );

      return user;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal login staf kasir';
      throw Exception(msg);
    }
  }

  /// Fetch latest user & store profile from /api/v1/auth/me and update token storage
  Future<CloudUser?> refreshProfile() async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return null;

      final response = await _apiClient.get('/api/v1/auth/me');
      final data = response['data'] as Map<String, dynamic>;
      final user = CloudUser.fromJson(data);

      await _tokenStorage.saveUserData(
        username: user.username,
        displayName: user.displayName,
        storeName: user.storeName,
        permissions: user.permissions,
      );
      await _tokenStorage.saveTier(
        tier: user.tier,
        canCloudSync: user.canCloudSync,
      );
      await _tokenStorage.setCloudMode(user.tier == 'PRO' || user.tier == 'PAID' || user.canCloudSync);

      return user;
    } catch (_) {
      return null;
    }
  }

  /// Switch cashier without unpairing store.
  Future<void> switchCashier() async {
    await _tokenStorage.clearCashierSession();
  }

  /// Unpair device from store after confirming owner password.
  Future<bool> unpairStore({required String ownerPassword}) async {
    final ownerUsername = await _tokenStorage.getUsername();
    final storeId = await _tokenStorage.getStoreId();
    if (ownerUsername == null || ownerUsername.isEmpty) {
      await _tokenStorage.clearAll();
      return true;
    }

    try {
      final body = <String, dynamic>{
        'username': ownerUsername,
        'password': ownerPassword,
        if (storeId != null) 'storeId': storeId,
      };

      await _apiClient.post('/api/v1/auth/login', body);
      // Password verified! Clear all local store pairing & cache
      await _tokenStorage.clearAll();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Password Owner salah';
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
