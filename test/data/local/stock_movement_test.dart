import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  test('Stock Movements Ledger records signed integer with scale 1000', () async {
    const storeId = 'store-test-01';
    const productId = 'prod-kopi-01';
    final now = DateTime.now();

    // 1. Stock In 10 units (+10000)
    await db.stockMovementDao.recordMovement(
      StockMovementsCompanion(
        id: const Value('mov-001'),
        storeId: const Value(storeId),
        productId: const Value(productId),
        type: const Value('IN'),
        quantityDelta: const Value(10000), // +10.000 units
        unitCost: const Value(5000),
        reason: const Value('Initial Purchase'),
        createdAt: Value(now),
      ),
    );

    // 2. Sale 2 units (-2000)
    await db.stockMovementDao.recordMovement(
      StockMovementsCompanion(
        id: const Value('mov-002'),
        storeId: const Value(storeId),
        productId: const Value(productId),
        type: const Value('SALE'),
        quantityDelta: const Value(-2000), // -2.000 units
        referenceType: const Value('TRANSACTION'),
        referenceId: const Value('trx-001'),
        createdAt: Value(now.add(const Duration(minutes: 5))),
      ),
    );

    final movements = await db.stockMovementDao.getMovementsByProduct(productId);
    expect(movements.length, equals(2));

    // Ledger sum check
    final totalDelta = movements.fold<int>(0, (sum, m) => sum + m.quantityDelta);
    expect(totalDelta, equals(8000)); // Remaining: 8 units (8000)
  });
}
