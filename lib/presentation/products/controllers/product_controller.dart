import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/local/app_database.dart';
import 'category_controller.dart';

final productListStreamProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchProducts(defaultStoreId);
});

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);

final filteredProductListProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productListStreamProvider);
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  final categoryFilter = ref.watch(selectedCategoryFilterProvider);

  return productsAsync.maybeWhen(
    data: (products) {
      return products.where((p) {
        final matchesCategory =
            categoryFilter == null || p.categoryId == categoryFilter;

        final matchesQuery = query.isEmpty ||
            p.name.toLowerCase().contains(query) ||
            (p.sku?.toLowerCase().contains(query) ?? false) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);

        return matchesCategory && matchesQuery;
      }).toList();
    },
    orElse: () => [],
  );
});

final productControllerProvider =
    StateNotifierProvider<ProductController, AsyncValue<void>>((ref) {
  return ProductController(ref);
});

class ProductController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  ProductController(this._ref) : super(const AsyncValue.data(null));

  Future<void> saveProduct({
    String? id,
    required String categoryId,
    required String name,
    String? sku,
    String? barcode,
    required int cost,
    required int sellingPrice,
    int initialStock = 0,
    int lowStockThreshold = 0,
    List<ProductVariantsCompanion>? variants,
  }) async {
    state = const AsyncValue.loading();
    try {
      final productRepo = _ref.read(productRepositoryProvider);
      final inventoryRepo = _ref.read(inventoryRepositoryProvider);
      final productId = id ?? _uuid.v4();
      final now = DateTime.now();

      final companion = ProductsCompanion(
        id: Value(productId),
        storeId: const Value(defaultStoreId),
        categoryId: Value(categoryId),
        name: Value(name.trim()),
        sku: Value(sku?.trim().isNotEmpty == true ? sku!.trim() : null),
        barcode: Value(barcode?.trim().isNotEmpty == true ? barcode!.trim() : null),
        cost: Value(cost),
        sellingPrice: Value(sellingPrice),
        stock: Value(initialStock),
        lowStockThreshold: Value(lowStockThreshold),
        active: const Value(true),
        discontinued: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await productRepo.saveProduct(companion);

      // Record initial stock movement if > 0
      if (initialStock > 0 && id == null) {
        await inventoryRepo.stockAdjustment(
          storeId: defaultStoreId,
          productId: productId,
          deltaQty: initialStock,
          reason: 'Initial Stock Creation',
        );
      }

      // Save variants if present
      if (variants != null && variants.isNotEmpty) {
        for (final v in variants) {
          await productRepo.saveVariant(v);
        }
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
