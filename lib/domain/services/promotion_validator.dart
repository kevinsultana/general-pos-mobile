import '../../core/utils/currency_formatter.dart';
import '../models/cart_item.dart';

class PromotionValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int discountAmount;

  const PromotionValidationResult.valid(this.discountAmount)
      : isValid = true,
        errorMessage = null;

  const PromotionValidationResult.invalid(this.errorMessage)
      : isValid = false,
        discountAmount = 0;
}

class PromotionValidator {
  const PromotionValidator();

  /// Authoritative domain calculation & validation for promotions/vouchers.
  /// Reusable across POS, cart, and payment validation.
  PromotionValidationResult validate({
    required bool active,
    DateTime? startDate,
    DateTime? endDate,
    int minSpend = 0,
    int? minimumPurchase,
    String? productId,
    required String discountType, // 'PERCENTAGE' or 'FIXED_AMOUNT' (legacy 'FIXED' is also supported)
    required int discountValue,
    required int cartSubtotal,
    required List<CartItem> cartItems,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    if (!active) {
      return const PromotionValidationResult.invalid('Promosi sedang tidak aktif');
    }

    if (startDate != null && now.isBefore(startDate)) {
      return const PromotionValidationResult.invalid('Promosi belum dimulai');
    }

    if (endDate != null && now.isAfter(endDate)) {
      return const PromotionValidationResult.invalid('Promosi telah berakhir');
    }

    // Scale is 1:1 whole Rupiah (Rp 1 = 1 unit)
    final effectiveMinSpend = minimumPurchase ?? minSpend;
    if (cartSubtotal < effectiveMinSpend) {
      final formattedMin = CurrencyFormatter.format(effectiveMinSpend);
      return PromotionValidationResult.invalid(
        'Belanja minimal $formattedMin untuk menggunakan promo ini',
      );
    }

    if (productId != null && productId.isNotEmpty) {
      final hasRequiredProduct =
          cartItems.any((item) => item.productId == productId);
      if (!hasRequiredProduct) {
        return const PromotionValidationResult.invalid(
          'Keranjang tidak memuat produk syarat promosi',
        );
      }
    }

    // Calculate discount amount
    int discount = 0;
    final normalizedType = discountType.trim().toUpperCase();
    if (normalizedType == 'PERCENTAGE') {
      if (discountValue <= 0) return const PromotionValidationResult.valid(0);
      final pct = discountValue > 100 ? 100 : discountValue;
      discount = (cartSubtotal * pct) ~/ 100;
    } else if (normalizedType == 'FIXED' || normalizedType == 'FIXED_AMOUNT') {
      discount = discountValue <= 0 ? 0 : discountValue;
    }

    // Protection: Discount cannot exceed subtotal
    if (discount > cartSubtotal) {
      discount = cartSubtotal;
    }

    return PromotionValidationResult.valid(discount);
  }
}
