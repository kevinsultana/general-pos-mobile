import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_providers.dart';
import '../../../data/local/app_database.dart';

const String defaultStoreId = AppConstants.defaultStoreId;

final categoryListStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchCategories(defaultStoreId);
});

final categoryControllerProvider =
    StateNotifierProvider<CategoryController, AsyncValue<void>>((ref) {
  return CategoryController(ref);
});

class CategoryController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  CategoryController(this._ref) : super(const AsyncValue.data(null));

  Future<Category> addCategory(String name) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(productRepositoryProvider);
      final id = _uuid.v4();
      final now = DateTime.now();

      await repo.saveCategory(
        CategoriesCompanion(
          id: Value(id),
          storeId: const Value(defaultStoreId),
          name: Value(name.trim()),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      state = const AsyncValue.data(null);
      return Category(
        id: id,
        storeId: defaultStoreId,
        name: name.trim(),
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
