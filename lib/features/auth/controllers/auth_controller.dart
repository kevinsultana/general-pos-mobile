import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/tenant_model.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/api_client.dart';

class AuthController with ChangeNotifier {
  final LocalRepository _localRepo = LocalRepository();
  final ApiClient _apiClient = ApiClient.instance;

  TenantModel? _currentTenant;
  bool _isLoading = false;
  String? _errorMessage;

  TenantModel? get currentTenant => _currentTenant;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentTenant != null;
  bool get isProOrPlus => _currentTenant?.isProOrPlus ?? false;

  Future<bool> checkAuthSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final tenant = await _localRepo.getActiveTenant();
      if (tenant != null && tenant.token != null) {
        _currentTenant = tenant;
        _apiClient.setToken(tenant.token);
        _isLoading = false;
        notifyListeners();

        // Cek pembaruan status plan secara asynchronous dari server
        refreshTenantPlan();
        return true;
      }
    } catch (e) {
      debugPrint('Check auth error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login({
    required String storeSlug,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.login,
        data: {
          'storeSlug': storeSlug.trim(),
          'email': email.trim(),
          'password': password,
          'clientType': 'mobile',
        },
      );

      final data = response.data['data'];
      final token = data['token'] as String;
      final tenantData = data['tenant'] as Map<String, dynamic>;
      final userData = data['user'] as Map<String, dynamic>;
      final branchData = data['activeBranch'] as Map<String, dynamic>?;

      final newTenant = TenantModel(
        id: tenantData['id'],
        name: tenantData['name'],
        slug: tenantData['slug'],
        plan: (tenantData['plan'] as String?) ?? 'FREE',
        planStatus: tenantData['planStatus'],
        ownerName: userData['name'],
        branchId: branchData?['id'],
        branchName: branchData?['name'],
        token: token,
      );

      // Simpan session ke database SQLite lokal
      await _localRepo.saveOrUpdateTenant(newTenant);
      _currentTenant = newTenant;
      _apiClient.setToken(token);

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (dioErr) {
      _isLoading = false;
      if (dioErr.response?.data != null && dioErr.response?.data['message'] != null) {
        _errorMessage = dioErr.response?.data['message'];
      } else {
        _errorMessage = 'Gagal terhubung ke server. Pastikan URL server aktif.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan login: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshTenantPlan() async {
    if (_currentTenant == null || _currentTenant!.token == null) return;

    try {
      final response = await _apiClient.dio.get(ApiConstants.me);
      final tenantData = response.data['data']?['tenant'];

      if (tenantData != null) {
        final serverPlan = (tenantData['plan'] as String?) ?? 'FREE';
        final serverStatus = tenantData['planStatus'] as String?;

        if (_currentTenant!.plan != serverPlan || _currentTenant!.planStatus != serverStatus) {
          final updated = _currentTenant!.copyWith(
            plan: serverPlan,
            planStatus: serverStatus,
          );
          await _localRepo.saveOrUpdateTenant(updated);
          _currentTenant = updated;
          notifyListeners();
        }
      }
    } catch (e) {
      // Offline fallback: tetap gunakan status lokal
      debugPrint('Background plan check skipped (offline): $e');
    }
  }

  Future<void> logout() async {
    await _localRepo.clearSession();
    _currentTenant = null;
    _apiClient.setToken(null);
    notifyListeners();
  }
}
