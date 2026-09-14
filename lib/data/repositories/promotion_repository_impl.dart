import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/i_promotion_repository.dart';
import '../local/app_database.dart';
import '../local/daos/promotion_dao.dart';

class PromotionRepositoryImpl implements IPromotionRepository {
  final PromotionDao _promotionDao;
  final Uuid _uuid;

  PromotionRepositoryImpl(this._promotionDao, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Promotion>> getPromotions(String storeId) {
    return _promotionDao.getAllPromotions(storeId);
  }

  @override
  Stream<List<Promotion>> watchPromotions(String storeId) {
    return _promotionDao.watchAllPromotions(storeId);
  }

  @override
  Future<Promotion?> getPromotionById(String id) {
    return _promotionDao.getPromotionById(id);
  }

  @override
  Future<Promotion?> getPromotionByCode(String storeId, String code) {
    return _promotionDao.getPromotionByCode(storeId, code);
  }

  @override
  Future<List<Promotion>> getActivePromotions(String storeId) {
    return _promotionDao.getActivePromotions(storeId);
  }

  @override
  Future<String> createPromotion({
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
  }) async {
    final now = DateTime.now();
    final promoId = _uuid.v4();

    await _promotionDao.insertPromotion(
      PromotionsCompanion(
        id: Value(promoId),
        storeId: Value(storeId),
        name: Value(name.trim()),
        code: Value(code?.trim().toUpperCase()),
        discountType: Value(discountType),
        discountValue: Value(discountValue),
        minSpend: Value(minSpend),
        startDate: Value(startDate),
        endDate: Value(endDate),
        productId: Value(productId),
        active: Value(active),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return promoId;
  }

  @override
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
  }) async {
    final existing = await _promotionDao.getPromotionById(id);
    if (existing == null) {
      throw Exception('Promosi dengan ID $id tidak ditemukan');
    }

    final now = DateTime.now();
    await _promotionDao.updatePromotion(
      PromotionsCompanion(
        id: Value(id),
        storeId: Value(storeId),
        name: Value(name.trim()),
        code: Value(code?.trim().toUpperCase()),
        discountType: Value(discountType),
        discountValue: Value(discountValue),
        minSpend: Value(minSpend),
        startDate: Value(startDate),
        endDate: Value(endDate),
        productId: Value(productId),
        active: Value(active),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> togglePromotionActive(String id, bool active) async {
    final existing = await _promotionDao.getPromotionById(id);
    if (existing == null) {
      throw Exception('Promosi dengan ID $id tidak ditemukan');
    }

    await _promotionDao.updatePromotion(
      existing.toCompanion(true).copyWith(
            active: Value(active),
            updatedAt: Value(DateTime.now()),
          ),
    );
  }

  @override
  Future<void> deletePromotion(String id) async {
    await _promotionDao.deletePromotion(id);
  }
}
