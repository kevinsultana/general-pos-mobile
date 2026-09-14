// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promotion_dao.dart';

// ignore_for_file: type=lint
mixin _$PromotionDaoMixin on DatabaseAccessor<AppDatabase> {
  $PromotionsTable get promotions => attachedDatabase.promotions;
  PromotionDaoManager get managers => PromotionDaoManager(this);
}

class PromotionDaoManager {
  final _$PromotionDaoMixin _db;
  PromotionDaoManager(this._db);
  $$PromotionsTableTableManager get promotions =>
      $$PromotionsTableTableManager(_db.attachedDatabase, _db.promotions);
}
