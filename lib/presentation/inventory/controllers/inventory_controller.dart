import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_providers.dart';
import '../../products/controllers/category_controller.dart';

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, AsyncValue<void>>((ref) {
  return InventoryController(ref);
});

class InventoryController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  InventoryController(this._ref) : super(const AsyncValue.data(null));

  Future<void> stockIn({
    required String productId,
    String? variantId,
    required int addedQty,
    required int unitCost,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(inventoryRepositoryProvider);
      await repo.stockIn(
        storeId: defaultStoreId,
        productId: productId,
        variantId: variantId,
        addedQty: addedQty,
        unitCost: unitCost,
        reason: reason,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> stockAdjustment({
    required String productId,
    String? variantId,
    required int deltaQty,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(inventoryRepositoryProvider);
      await repo.stockAdjustment(
        storeId: defaultStoreId,
        productId: productId,
        variantId: variantId,
        deltaQty: deltaQty,
        reason: reason,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
