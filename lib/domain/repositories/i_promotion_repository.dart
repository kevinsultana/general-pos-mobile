import '../../data/local/app_database.dart';

abstract class IPromotionRepository {
  Future<List<Promotion>> getPromotions(String storeId);

  Stream<List<Promotion>> watchPromotions(String storeId);

  Future<Promotion?> getPromotionById(String id);

  Future<Promotion?> getPromotionByCode(String storeId, String code);

  Future<List<Promotion>> getActivePromotions(String storeId);

  Future<String> createPromotion({
    required String storeId,
    required String name,
    String? code,
    required String discountType, // 'PERCENTAGE' or 'FIXED'
    required int discountValue,
    int minSpend = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
    bool active = true,
  });

  Future<void> updatePromotion({
    required String id,
    required String storeId,
    required String name,
    String? code,
    required String discountType,
    required int discountValue,
    int minSpend = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
    bool active = true,
  });

  Future<void> togglePromotionActive(String id, bool active);

  Future<void> deletePromotion(String id);
}
