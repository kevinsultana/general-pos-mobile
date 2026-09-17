import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/local/app_database.dart';

final productListStreamProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final storeId = ref.watch(activeStoreIdProvider);
  return repo.watchProducts(storeId);
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
      final storeId = _ref.read(activeStoreIdProvider);
      final productId = id ?? _uuid.v4();
      final now = DateTime.now();

      final hasVariants = variants != null && variants.isNotEmpty;

      final companion = ProductsCompanion(
        id: Value(productId),
        storeId: Value(storeId),
        categoryId: Value(categoryId),
        name: Value(name.trim()),
        sku: Value(sku?.trim().isNotEmpty == true ? sku!.trim() : null),
        barcode: Value(barcode?.trim().isNotEmpty == true ? barcode!.trim() : null),
        cost: Value(cost),
        sellingPrice: Value(sellingPrice),
        stock: Value(id == null ? 0 : initialStock),
        lowStockThreshold: Value(lowStockThreshold),
        active: const Value(true),
        discontinued: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await productRepo.saveProduct(companion);

      // Save variants if present
      if (hasVariants) {
        for (final v in variants) {
          if (id == null) {
            // Initial creation: save with 0 stock, then adjust to record ledger
            final initialVarStock = v.stock.value;
            final vWithZero = v.copyWith(stock: const Value(0));
            await productRepo.saveVariant(vWithZero);
            if (initialVarStock > 0) {
              await inventoryRepo.stockAdjustment(
                storeId: storeId,
                productId: productId,
                variantId: v.id.value,
                deltaQty: initialVarStock,
                reason: 'Initial Stock Creation',
              );
            }
          } else {
            await productRepo.saveVariant(v);
          }
        }
        // Ensure master stock is reconciled with variants
        final allVariants = await productRepo.getVariants(productId);
        final sumStock = allVariants.fold<int>(0, (sum, item) => sum + item.stock);
        await productRepo.updateStock(productId, sumStock);
      } else if (initialStock > 0 && id == null) {
        // Record initial stock movement if > 0
        await inventoryRepo.stockAdjustment(
          storeId: storeId,
          productId: productId,
          deltaQty: initialStock,
          reason: 'Initial Stock Creation',
        );
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
