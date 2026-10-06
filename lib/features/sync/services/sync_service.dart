import 'package:flutter/foundation.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/tenant_model.dart';
import '../../../core/network/api_client.dart';

class SyncService {
  final ApiClient _apiClient = ApiClient.instance;
  final LocalRepository _localRepo = LocalRepository();

  Future<int> getPendingCount(String tenantId) async {
    try {
      return await _localRepo.getPendingSyncCount(tenantId);
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }

  Future<bool> executeSync(TenantModel tenant) async {
    try {
      // 1. Push pending transactions and shifts
      final pushSuccess = await pushPendingData(tenant);

      // 2. Pull latest catalog updates from cloud
      await _pullCatalogFromCloud(tenant.id);

      return pushSuccess;
    } catch (e) {
      debugPrint('Execute sync error: $e');
      return false;
    }
  }

  Future<bool> pushPendingData(TenantModel tenant) async {
    try {
      final pendingTransactions = await _localRepo.getPendingTransactions(tenant.id);
      final pendingItems = await _localRepo.getPendingTransactionItems(tenant.id);
      final pendingShifts = await _localRepo.getPendingShifts(tenant.id);

      if (pendingTransactions.isEmpty && pendingShifts.isEmpty) {
        return true;
      }

      final payload = {
        'tenantId': tenant.id,
        'shifts': pendingShifts.map((s) => s.toMap()).toList(),
        'transactions': pendingTransactions.map((t) => t.toMap()).toList(),
        'transactionItems': pendingItems.map((i) => i.toMap()).toList(),
      };

      final response = await _apiClient.dio.post(
        ApiConstants.syncPush,
        data: payload,
      );

      if (response.data['success'] == true) {
        final syncedTrxIds = pendingTransactions.map((t) => t.id).toList();
        final syncedShiftIds = pendingShifts.map((s) => s.id).toList();

        await _localRepo.markTransactionsSynced(syncedTrxIds);
        await _localRepo.markShiftsSynced(syncedShiftIds);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sync push error: $e');
      return false;
    }
  }

  Future<bool> initialUploadAfterUpgrade(TenantModel tenant) async {
    try {
      final categories = await _localRepo.getCategories(tenant.id);
      final products = await _localRepo.getProducts(tenant.id);
      final shifts = await _localRepo.getAllShifts(tenant.id);
      final transactions = await _localRepo.getAllTransactions(tenant.id);
      final items = await _localRepo.getAllTransactionItems(tenant.id);
      final customers = await _localRepo.getCustomers(tenant.id);
      final promotions = await _localRepo.getPromotions(tenant.id);

      final payload = {
        'tenantId': tenant.id,
        'categories': categories.map((c) => c.toMap()).toList(),
        'products': products.map((p) => p.toMap()).toList(),
        'shifts': shifts.map((s) => s.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'transactionItems': items.map((i) => i.toMap()).toList(),
        'customers': customers.map((c) => c.toMap()).toList(),
        'promotions': promotions.map((pr) => pr.toMap()).toList(),
      };

      final response = await _apiClient.dio.post(
        ApiConstants.syncInitialUpload,
        data: payload,
      );

      if (response.data['success'] == true) {
        final allTrxIds = transactions.map((t) => t.id).toList();
        final allShiftIds = shifts.map((s) => s.id).toList();

        await _localRepo.markTransactionsSynced(allTrxIds);
        await _localRepo.markShiftsSynced(allShiftIds);

        // Unduh katalog terbaru dari cloud
        await _pullCatalogFromCloud(tenant.id);

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sync failed (offline or network error): $e');
      return false;
    }
  }

  Future<void> _pullCatalogFromCloud(String tenantId) async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.syncPull);
      if (response.data['success'] == true) {
        final categories = response.data['data']['categories'] as List? ?? [];
        final products = response.data['data']['products'] as List? ?? [];

        // Simpan atau perbarui kategori di SQLite lokal
        for (final catMap in categories) {
          final localCat = await _localRepo.getCategories(tenantId);
          if (!localCat.any((c) => c.id == catMap['id'])) {
            await _localRepo.insertCategory(
              CategoryModel(
                id: catMap['id'],
                tenantId: tenantId,
                name: catMap['name'],
                sortOrder: catMap['sortOrder'] ?? 0,
                syncStatus: 'SYNCED',
              ),
            );
          }
        }

        // Simpan atau perbarui produk di SQLite lokal
        for (final prodMap in products) {
          final localProd = await _localRepo.getProducts(tenantId);
          if (!localProd.any((p) => p.id == prodMap['id'])) {
            await _localRepo.insertProduct(
              ProductModel(
                id: prodMap['id'],
                tenantId: tenantId,
                categoryId: prodMap['categoryId'],
                name: prodMap['name'],
                price: (prodMap['price'] as num).toDouble(),
                costPrice: (prodMap['costPrice'] as num?)?.toDouble() ?? 0,
                imageUrl: prodMap['imageUrl'],
                isActive: prodMap['isActive'] ?? true,
                syncStatus: 'SYNCED',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Pull sync error: $e');
    }
  }
}
