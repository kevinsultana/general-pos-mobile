import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';
import 'package:mobile_pos/domain/services/promotion_validator.dart';

void main() {
  const validator = PromotionValidator();

  final dummyItem1 = CartItem(
    productId: 'prod-coffee',
    productName: 'Kopi Susu',
    quantity: 2,
    unitPrice: 15000,
    unitCostSnapshot: 6000,
  );

  final dummyItem2 = CartItem(
    productId: 'prod-snack',
    productName: 'Croissant',
    quantity: 1,
    unitPrice: 20000,
    unitCostSnapshot: 10000,
  );

  final testItems = [dummyItem1, dummyItem2];
  const testSubtotal = 50000; // (2*15000) + 20000

  group('PromotionValidator Tests', () {
    test('Inactive promotion returns invalid', () {
      final result = validator.validate(
        active: false,
        discountType: 'PERCENTAGE',
        discountValue: 10,
        cartSubtotal: testSubtotal,
        cartItems: testItems,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('tidak aktif'));
      expect(result.discountAmount, equals(0));
    });

    test('Promotion before start date returns invalid', () {
      final now = DateTime(2026, 9, 15);
      final startDate = DateTime(2026, 9, 20);

      final result = validator.validate(
        active: true,
        startDate: startDate,
        discountType: 'PERCENTAGE',
        discountValue: 10,
        cartSubtotal: testSubtotal,
        cartItems: testItems,
        currentTime: now,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('belum dimulai'));
    });

    test('Promotion after end date returns invalid', () {
      final now = DateTime(2026, 9, 25);
      final endDate = DateTime(2026, 9, 20);

      final result = validator.validate(
        active: true,
        endDate: endDate,
        discountType: 'PERCENTAGE',
        discountValue: 10,
        cartSubtotal: testSubtotal,
        cartItems: testItems,
        currentTime: now,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('telah berakhir'));
    });

    test('Subtotal below minSpend returns invalid', () {
      final result = validator.validate(
        active: true,
        minSpend: 75000,
        discountType: 'PERCENTAGE',
        discountValue: 10,
        cartSubtotal: testSubtotal, // 50.000 < 75.000
        cartItems: testItems,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Belanja minimal'));
    });

    test('Missing required product condition returns invalid', () {
      final result = validator.validate(
        active: true,
        productId: 'prod-cake-not-in-cart',
        discountType: 'FIXED',
        discountValue: 5000,
        cartSubtotal: testSubtotal,
        cartItems: testItems,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('tidak memuat produk syarat'));
    });

    test('Valid percentage promotion calculates correct discount', () {
      final result = validator.validate(
        active: true,
        minSpend: 30000,
        productId: 'prod-coffee',
        discountType: 'PERCENTAGE',
        discountValue: 15, // 15% of 50.000 = 7.500
        cartSubtotal: testSubtotal,
        cartItems: testItems,
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.discountAmount, equals(7500));
    });

    test('Valid fixed promotion calculates correct discount', () {
      final result = validator.validate(
        active: true,
        minSpend: 40000,
        discountType: 'FIXED',
        discountValue: 10000,
        cartSubtotal: testSubtotal,
        cartItems: testItems,
      );

      expect(result.isValid, isTrue);
      expect(result.discountAmount, equals(10000));
    });

    test('Fixed discount exceeding subtotal is clamped to subtotal', () {
      final result = validator.validate(
        active: true,
        discountType: 'FIXED',
        discountValue: 80000, // 80.000 > 50.000
        cartSubtotal: testSubtotal,
        cartItems: testItems,
      );

      expect(result.isValid, isTrue);
      expect(result.discountAmount, equals(testSubtotal)); // Clamped to 50.000
    });
  });
}
