import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/store_repository_impl.dart';

void main() {
  late AppDatabase db;
  late StoreRepositoryImpl storeRepo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    storeRepo = StoreRepositoryImpl(db.storeDao);
  });

  tearDown(() async {
    await db.close();
  });

  test('Drift AppDatabase initializes and handles Store with Cash Rounding settings', () async {
    const storeId = 'store-test-01';
    final now = DateTime.now();

    await storeRepo.saveStore(
      StoresCompanion(
        id: const Value(storeId),
        name: const Value('Warung Kopi Mantap'),
        ownerName: const Value('Budi'),
        currency: const Value('IDR'),
        timezone: const Value('Asia/Jakarta'),
        cashRoundingEnabled: const Value(true),
        cashRoundingIncrement: const Value(500),
        cashRoundingMode: const Value('ROUND_NEAREST'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final store = await storeRepo.getStore(storeId);
    expect(store, isNotNull);
    expect(store!.name, equals('Warung Kopi Mantap'));
    expect(store.cashRoundingEnabled, isTrue);
    expect(store.cashRoundingIncrement, equals(500));
    expect(store.cashRoundingMode, equals('ROUND_NEAREST'));
  });

  test('AppDatabase has schemaVersion 5 and promotions/customers/orderType tables are queryable', () async {
    expect(db.schemaVersion, equals(5));

    // Ensure self-healing DDL can execute idempotently
    await db.promotionDao.ensureTableExists();
    await db.customerDao.ensureTableExists();

    final promos = await db.promotionDao.getAllPromotions('store-test-01');
    expect(promos, isEmpty);

    final customers = await db.customerDao.getAllCustomers('store-test-01');
    expect(customers, isEmpty);
  });
}
