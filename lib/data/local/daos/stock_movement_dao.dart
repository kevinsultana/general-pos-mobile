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
