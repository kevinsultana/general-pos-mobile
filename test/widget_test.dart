import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/product_model.dart';
import 'package:mobile/core/models/promotion_model.dart';
import 'package:mobile/core/models/cart_item_model.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

void main() {
  group('OmniPOS Mobile Core Logic Tests', () {
    test('CurrencyFormatter formats IDR correctly', () {
      expect(CurrencyFormatter.format(15000), 'Rp 15.000');
      expect(CurrencyFormatter.format(0), 'Rp 0');
      expect(CurrencyFormatter.format(1250500), 'Rp 1.250.500');
    });

    test('PromotionModel calculates percentage discount correctly', () {
      final promo = PromotionModel(
        id: 'promo-1',
        tenantId: 'tenant-1',
        name: 'Diskon 10%',
        code: 'DISKON10',
        discountType: 'PERCENTAGE',
        discountValue: 10,
        minOrderAmount: 50000,
      );

      // Below min order
      expect(promo.calculateDiscount(40000), 0.0);

      // Met min order
      expect(promo.calculateDiscount(100000), 10000.0);
    });

    test('PromotionModel calculates fixed nominal discount correctly', () {
      final promo = PromotionModel(
        id: 'promo-2',
        tenantId: 'tenant-1',
        name: 'Potongan 5000',
        code: 'HEMAT5K',
        discountType: 'FIXED',
        discountValue: 5000,
        minOrderAmount: 20000,
      );

      expect(promo.calculateDiscount(15000), 0.0);
      expect(promo.calculateDiscount(30000), 5000.0);
    });

    test('CartItemModel subtotal calculation is exact', () {
      final product = ProductModel(
        id: 'p-1',
        tenantId: 't-1',
        categoryId: 'c-1',
        name: 'Es Kopi Susu',
        price: 18000,
        costPrice: 8000,
        stock: 50,
      );

      final item = CartItemModel(product: product, quantity: 3, notes: 'Less sugar');
      expect(item.subtotal, 54000);
      expect(item.notes, 'Less sugar');
    });
  });
}
