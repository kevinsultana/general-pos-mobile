import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/local/app_database.dart';
import 'package:mobile_pos/data/repositories/promotion_repository_impl.dart';

void main() {
  late AppDatabase db;
  late PromotionRepositoryImpl promoRepo;
  const storeId = 'store-test-01';

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    promoRepo = PromotionRepositoryImpl(db.promotionDao);

    await db.into(db.stores).insert(
          StoresCompanion.insert(
            id: storeId,
            name: 'Promo Test Store',
            currency: const Value('IDR'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('Promotion CRUD and voucher lookup by code works', () async {
    // 1. Create promotion
    final promoId = await promoRepo.createPromotion(
      storeId: storeId,
      name: 'Voucher Gajian 10%',
      code: 'gajian10', // lowercase input should be stored uppercase
      discountType: 'PERCENTAGE',
      discountValue: 10,
      minSpend: 50000,
    );

    // 2. Query by code
    final byCode = await promoRepo.getPromotionByCode(storeId, 'GAJIAN10');
    expect(byCode, isNotNull);
    expect(byCode?.id, equals(promoId));
    expect(byCode?.code, equals('GAJIAN10'));
    expect(byCode?.minSpend, equals(50000));
    expect(byCode?.minimumPurchase, equals(50000)); // PromotionExt alias
    expect(byCode?.type, equals('PERCENTAGE')); // PromotionExt alias
    expect(byCode?.value, equals(10)); // PromotionExt alias
    expect(byCode?.active, isTrue);

    // 3. Toggle active
    await promoRepo.togglePromotionActive(promoId, false);
    final deactivated = await promoRepo.getPromotionById(promoId);
    expect(deactivated?.active, isFalse);

    // 4. Get active promotions
    final activeList = await promoRepo.getActivePromotions(storeId);
    expect(activeList, isEmpty);

    // 5. Delete promotion
    await promoRepo.deletePromotion(promoId);
    final deleted = await promoRepo.getPromotionById(promoId);
    expect(deleted, isNull);
  });

  test('Promotion creation with minimumPurchase alias and FIXED normalization works', () async {
    final promoId = await promoRepo.createPromotion(
      storeId: storeId,
      name: 'Voucher Potongan Rp 15.000',
      code: 'HEMAT15',
      discountType: 'FIXED', // legacy FIXED should normalize to FIXED_AMOUNT
      discountValue: 15000,
      minimumPurchase: 75000, // minimumPurchase alias for minSpend
    );

    final promo = await promoRepo.getPromotionById(promoId);
    expect(promo, isNotNull);
    expect(promo?.discountType, equals('FIXED_AMOUNT'));
    expect(promo?.minSpend, equals(75000));
    expect(promo?.minimumPurchase, equals(75000));
    expect(promo?.discountValue, equals(15000));
    expect(promo?.value, equals(15000));
  });
}
