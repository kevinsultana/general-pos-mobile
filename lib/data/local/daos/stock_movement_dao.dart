import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/inventory_tables.dart';

part 'stock_movement_dao.g.dart';

@DriftAccessor(tables: [StockMovements])
class StockMovementDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementDaoMixin {
  StockMovementDao(super.db);

  Future<void> recordMovement(StockMovementsCompanion movement) {
    return into(stockMovements).insert(movement);
  }

  /// Records a positive REFUND_REVERSAL stock movement (scale 1000)
  Future<void> recordRefundReversal({
    required String id,
    required String storeId,
    required String productId,
    String? variantId,
    required int quantityDelta,
    required String referenceId,
    String? reason,
    DateTime? createdAt,
  }) {
    return into(stockMovements).insert(
      StockMovementsCompanion(
        id: Value(id),
        storeId: Value(storeId),
        productId: Value(productId),
        variantId: Value(variantId),
        type: const Value('REFUND_REVERSAL'),
        quantityDelta: Value(quantityDelta.abs()), // Must be positive
        referenceType: const Value('REFUND'),
        referenceId: Value(referenceId),
        reason: Value(reason),
        createdAt: Value(createdAt ?? DateTime.now()),
      ),
    );
  }

  Future<List<StockMovement>> getMovementsByReference(String referenceId) {
    return (select(stockMovements)
          ..where((tbl) => tbl.referenceId.equals(referenceId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<List<StockMovement>> getMovementsByProduct(String productId) {
    return (select(stockMovements)
          ..where((tbl) => tbl.productId.equals(productId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<List<StockMovement>> getRecentMovements(String storeId, {int limit = 50}) {
    return (select(stockMovements)
          ..where((tbl) => tbl.storeId.equals(storeId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(limit))
        .get();
  }
}
