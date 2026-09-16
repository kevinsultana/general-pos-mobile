import '../../data/local/app_database.dart';

/// Extension on Drift [Promotion] to provide alignment with Backend Prisma naming
/// and 1:1 whole Rupiah scale guarantees.
extension PromotionExt on Promotion {
  /// Equivalent to Prisma `minimumPurchase Decimal(18,2)` in backend.
  /// In POS IDR, this is stored as whole Rupiah without fractional cents (Rp 1 = 1 unit).
  /// E.g. Rp 50.000 = 50000.
  int get minimumPurchase => minSpend;

  /// Equivalent to Prisma `type DiscountType` ('PERCENTAGE' | 'FIXED_AMOUNT').
  String get type => discountType;

  /// Equivalent to Prisma `value Decimal(18,2)`.
  /// Represents percentage (e.g. 10 for 10%) or fixed nominal Rupiah (e.g. 10000).
  int get value => discountValue;

  /// Equivalent to Prisma `startAt DateTime`.
  DateTime? get startAt => startDate;

  /// Equivalent to Prisma `endAt DateTime`.
  DateTime? get endAt => endDate;
}
