import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';

void main() {
  late AppDatabase db;
  late DraftRepositoryImpl draftRepo;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    draftRepo = DraftRepositoryImpl(db);

    // Seed default store
    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: 'default-store',
            name: 'Toko Berkah POS',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    // Seed product with initial stock of 20
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-kopi',
            storeId: 'default-store',
            categoryId: 'cat-test',
            name: 'Kopi Espresso',
            sku: const Value('KOP-001'),
            sellingPrice: 15000,
            cost: 8000,
            stock: 20,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('Saving a draft does NOT affect product stock and does NOT record stock movements', () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-kopi',
        productName: 'Kopi Espresso',
        sku: 'KOP-001',
        quantity: 5,
        unitPrice: 15000,
        unitCostSnapshot: 8000,
      ),
    ];

    // Check stock BEFORE saving draft
    final initialProduct = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-kopi')))
        .getSingle();
    expect(initialProduct.stock, equals(20));

    // Save draft
    final draftId = await draftRepo.saveDraft(
      storeId: 'default-store',
      orderType: 'DINE_IN',
      queueNumber: '#03',
      subtotal: 75000,
      discountTotal: 0,
      total: 75000,
      items: cartItems,
    );

    expect(draftId, isNotEmpty);

    // Verify draft record exists in database with status DRAFT
    final savedDraft = await db.transactionDao.getTransactionById(draftId);
    expect(savedDraft, isNotNull);
    expect(savedDraft!.status, equals('DRAFT'));
    expect(savedDraft.orderType, equals('DINE_IN'));
    expect(savedDraft.queueNumber, equals('#03'));
    expect(savedDraft.total, equals(75000));

    // Verify draft items exist with correct snapshot
    final items = await draftRepo.getDraftItems(draftId);
    expect(items.length, equals(1));
    expect(items.first.productNameSnapshot, equals('Kopi Espresso'));
    expect(items.first.unitCostSnapshot, equals(8000));
    expect(items.first.quantity, equals(5));

    // CRITICAL PRD RULE VERIFICATION:
    // 1. Product stock must remain exactly 20 (not 15!)
    final productAfterDraft = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-kopi')))
        .getSingle();
    expect(productAfterDraft.stock, equals(20));

    // 2. Stock movements ledger must have 0 entries
    final movements = await db.select(db.stockMovements).get();
    expect(movements.isEmpty, isTrue);
  });

  test('Draft can be deleted cleanly without side-effects', () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-kopi',
        productName: 'Kopi Espresso',
        quantity: 2,
        unitPrice: 15000,
        unitCostSnapshot: 8000,
      ),
    ];

    final draftId = await draftRepo.saveDraft(
      storeId: 'default-store',
      orderType: 'TAKEAWAY',
      subtotal: 30000,
      discountTotal: 0,
      total: 30000,
      items: cartItems,
    );

    // Delete draft
    await draftRepo.deleteDraft(draftId);

    // Verify draft and its items are removed
    final draftAfterDelete = await db.transactionDao.getTransactionById(draftId);
    expect(draftAfterDelete, isNull);

    final itemsAfterDelete = await draftRepo.getDraftItems(draftId);
    expect(itemsAfterDelete.isEmpty, isTrue);

    // Product stock still intact
    final prod = await (db.select(db.products)
          ..where((tbl) => tbl.id.equals('prod-kopi')))
        .getSingle();
    expect(prod.stock, equals(20));
  });

  test('watchDrafts streams drafts with storeId or legacy default-store', () async {
    final cartItems = [
      const CartItem(
        productId: 'prod-kopi',
        productName: 'Kopi Espresso',
        quantity: 1,
        unitPrice: 15000,
        unitCostSnapshot: 8000,
      ),
    ];

    await draftRepo.saveDraft(
      storeId: 'store-default-01',
      orderType: 'DINE_IN',
      subtotal: 15000,
      discountTotal: 0,
      total: 15000,
      items: cartItems,
    );

    await draftRepo.saveDraft(
      storeId: 'default-store',
      orderType: 'TAKEAWAY',
      subtotal: 15000,
      discountTotal: 0,
      total: 15000,
      items: cartItems,
    );

    final drafts = await draftRepo.watchDrafts('store-default-01').first;
    expect(drafts.length, equals(2));
  });
}
