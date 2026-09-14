import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/domain/models/cart_item.dart';
import 'package:mobile_pos/domain/services/transaction_calculator.dart';

void main() {
  const calculator = TransactionCalculator();

  group('TransactionCalculator — Discount Calculations', () {
    test('Percentage discount calculates properly', () {
      final discount = calculator.calculateDiscount(
        subtotal: 50000,
        discountType: 'PERCENTAGE',
        discountValue: 10,
      );
      expect(discount, equals(5000));
    });

    test('Fixed discount calculates properly', () {
      final discount = calculator.calculateDiscount(
        subtotal: 50000,
        discountType: 'FIXED',
        discountValue: 7500,
      );
      expect(discount, equals(7500));
    });

    test('Discount greater than subtotal is clamped to subtotal', () {
      final discount = calculator.calculateDiscount(
        subtotal: 20000,
        discountType: 'FIXED',
        discountValue: 50000,
      );
      expect(discount, equals(20000));

      final percentOver = calculator.calculateDiscount(
        subtotal: 20000,
        discountType: 'PERCENTAGE',
        discountValue: 150,
      );
      expect(percentOver, equals(20000));
    });

    test('Negative or zero discount value returns 0', () {
      expect(
        calculator.calculateDiscount(
          subtotal: 20000,
          discountType: 'PERCENTAGE',
          discountValue: 0,
        ),
        equals(0),
      );
      expect(
        calculator.calculateDiscount(
          subtotal: 20000,
          discountType: 'FIXED',
          discountValue: -500,
        ),
        equals(0),
      );
      expect(
        calculator.calculateDiscount(
          subtotal: 20000,
          discountType: null,
          discountValue: 1000,
        ),
        equals(0),
      );
    });
  });

  group('TransactionCalculator — Order Calculation & Profitability', () {
    test('Calculates multi-item cart with line discounts and order discount', () {
      final items = [
        const CartItem(
          productId: 'prod-1',
          productName: 'Kopi Susu',
          quantity: 2,
          unitPrice: 18000, // Subtotal: 36000
          unitCostSnapshot: 10000, // Total cost: 20000
          discountType: 'PERCENTAGE',
          discountValue: 10, // Line discount: 3600 -> Total: 32400
        ),
        const CartItem(
          productId: 'prod-2',
          productName: 'Roti Bakar',
          quantity: 1,
          unitPrice: 15000, // Subtotal: 15000
          unitCostSnapshot: 8000, // Total cost: 8000
          discountType: 'FIXED',
          discountValue: 2000, // Line discount: 2000 -> Total: 13000
        ),
      ];

      // Order subtotal = 32400 + 13000 = 45400
      // Order discount = 10% of 45400 = 4540
      // Grand total = 45400 - 4540 = 40860
      // Total cost = 20000 + 8000 = 28000
      // Gross profit = 40860 - 28000 = 12860
      // Total items = 2 + 1 = 3
      final result = calculator.calculate(
        items: items,
        orderDiscountType: 'PERCENTAGE',
        orderDiscountValue: 10,
      );

      expect(result.rawSubtotal, equals(51000));
      expect(result.itemDiscountsTotal, equals(5600));
      expect(result.orderSubtotal, equals(45400));
      expect(result.orderDiscountAmount, equals(4540));
      expect(result.grandTotal, equals(40860));
      expect(result.totalCost, equals(28000));
      expect(result.grossProfit, equals(12860));
      expect(result.totalItemCount, equals(3));
    });

    test('Empty cart returns all zero metrics', () {
      final result = calculator.calculate(items: []);

      expect(result.rawSubtotal, equals(0));
      expect(result.itemDiscountsTotal, equals(0));
      expect(result.orderSubtotal, equals(0));
      expect(result.orderDiscountAmount, equals(0));
      expect(result.grandTotal, equals(0));
      expect(result.totalCost, equals(0));
      expect(result.grossProfit, equals(0));
      expect(result.totalItemCount, equals(0));
    });
  });
}
