import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/i_inventory_repository.dart';
import '../../domain/services/cost_calculator.dart';
import '../local/app_database.dart';
import '../local/daos/product_dao.dart';
import '../local/daos/stock_movement_dao.dart';

class InventoryRepositoryImpl implements IInventoryRepository {
  final AppDatabase _db;
  final ProductDao _productDao;
  final StockMovementDao _stockMovementDao;
  final Uuid _uuid;
  final bool _isCloudMode;
  final String? _deviceId;

  InventoryRepositoryImpl(
    this._db,
    this._productDao,
    this._stockMovementDao, [
    Uuid? uuid,
    bool isCloudMode = false,
    String? deviceId,
  ])  : _uuid = uuid ?? const Uuid(),
        _isCloudMode = isCloudMode,
        _deviceId = deviceId;

  @override
  Future<void> stockIn({
    required String storeId,
    required String productId,
    String? variantId,
    required int addedQty,
    required int unitCost,
    String? reason,
  }) async {
    await _db.transaction(() async {
      final product = await _productDao.getProductById(productId);
      if (product == null) {
        throw ArgumentError('Product not found with id: $productId');
      }

      final existingStock = product.stock;
      final existingCost = product.cost;

      final newCost = CostCalculator.calculateWeightedAverageCost(
        existingQty: existingStock,
        existingCost: existingCost,
        addedQty: addedQty,
        addedCost: unitCost,
      );

      final newStock = existingStock + addedQty;

      // Update product stock and cost
      await (_db.update(_db.products)..where((tbl) => tbl.id.equals(productId))).write(
        ProductsCompanion(
          stock: Value(newStock),
          cost: Value(newCost),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Record in stock movement ledger with scale 1000
      await _stockMovementDao.recordMovement(
        StockMovementsCompanion(
          id: Value(_uuid.v4()),
          storeId: Value(storeId),
          productId: Value(productId),
          variantId: Value(variantId),
          type: const Value('IN'),
          quantityDelta: Value(addedQty * 1000), // Scale 1000
          unitCost: Value(unitCost),
          reason: Value(reason ?? 'Stock In Purchase'),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> stockAdjustment({
    required String storeId,
    required String productId,
    String? variantId,
    required int deltaQty,
    required String reason,
  }) async {
    await _db.transaction(() async {
      final product = await _productDao.getProductById(productId);
      if (product == null) {
        throw ArgumentError('Product not found with id: $productId');
      }

      final newStock = product.stock + deltaQty;

      // Update stock
      await _productDao.updateStock(productId, newStock);

      // Record in ledger with signed integer scale 1000
      await _stockMovementDao.recordMovement(
        StockMovementsCompanion(
          id: Value(_uuid.v4()),
          storeId: Value(storeId),
          productId: Value(productId),
          variantId: Value(variantId),
          type: const Value('ADJUSTMENT'),
          quantityDelta: Value(deltaQty * 1000), // Scale 1000
          unitCost: Value(product.cost),
          reason: Value(reason),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Enqueue ADJUST_STOCK sync event if in Cloud Mode
      if (_isCloudMode) {
        final eventId = _uuid.v4();
        await _db.syncEventDao.insertEvent(
          SyncEventsCompanion.insert(
            id: eventId,
            storeId: storeId,
            deviceId: _deviceId ?? 'pos-device',
            entityType: 'StockMovement',
            entityId: eventId,
            operation: 'ADJUST_STOCK',
            payload: jsonEncode({
              'productId': productId,
              'variantId': variantId,
              'quantityDelta': deltaQty,
              'reason': reason,
              'type': 'ADJUSTMENT',
            }),
            status: 'PENDING',
            createdAt: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  Future<List<StockMovement>> getProductStockMovements(String productId) {
    return _stockMovementDao.getMovementsByProduct(productId);
  }
}
