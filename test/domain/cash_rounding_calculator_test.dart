import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/domain/services/cash_rounding_calculator.dart';

void main() {
  group('CashRoundingCalculator Tests', () {
    const calculator = CashRoundingCalculator();

    group('ROUND_NEAREST (Half-Up)', () {
      test('Increment 500: Rp9.200 rounds down to Rp9.000 (-200)', () {
        final result = calculator.calculate(
          amount: 9200,
          mode: CashRoundingMode.roundNearest,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9000));
        expect(result.roundingAmount, equals(-200));
      });

      test('Increment 500: Rp9.250 (half-way) rounds up to Rp9.500 (+250)', () {
        final result = calculator.calculate(
          amount: 9250,
          mode: CashRoundingMode.roundNearest,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9500));
        expect(result.roundingAmount, equals(250));
      });

      test('Increment 500: Rp9.300 rounds up to Rp9.500 (+200)', () {
        final result = calculator.calculate(
          amount: 9300,
          mode: CashRoundingMode.roundNearest,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9500));
        expect(result.roundingAmount, equals(200));
      });

      test('Increment 100: Rp9.950 rounds up to Rp10.000 (+50)', () {
        final result = calculator.calculate(
          amount: 9950,
          mode: CashRoundingMode.roundNearest,
          increment: 100,
        );
        expect(result.roundedAmount, equals(10000));
        expect(result.roundingAmount, equals(50));
      });

      test('Increment 1000: Rp9.499 rounds down to Rp9.000 (-499)', () {
        final result = calculator.calculate(
          amount: 9499,
          mode: CashRoundingMode.roundNearest,
          increment: 1000,
        );
        expect(result.roundedAmount, equals(9000));
        expect(result.roundingAmount, equals(-499));
      });

      test('Increment 1000: Rp9.500 rounds up to Rp10.000 (+500)', () {
        final result = calculator.calculate(
          amount: 9500,
          mode: CashRoundingMode.roundNearest,
          increment: 1000,
        );
        expect(result.roundedAmount, equals(10000));
        expect(result.roundingAmount, equals(500));
      });
    });

    group('ROUND_DOWN (Floor)', () {
      test('Increment 500: Rp9.999 rounds down to Rp9.500 (-499)', () {
        final result = calculator.calculate(
          amount: 9999,
          mode: CashRoundingMode.roundDown,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9500));
        expect(result.roundingAmount, equals(-499));
      });

      test('Increment 500: Rp9.250 rounds down to Rp9.000 (-250)', () {
        final result = calculator.calculate(
          amount: 9250,
          mode: CashRoundingMode.roundDown,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9000));
        expect(result.roundingAmount, equals(-250));
      });
    });

    group('ROUND_UP (Ceil)', () {
      test('Increment 500: Rp9.001 rounds up to Rp9.500 (+499)', () {
        final result = calculator.calculate(
          amount: 9001,
          mode: CashRoundingMode.roundUp,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9500));
        expect(result.roundingAmount, equals(499));
      });

      test('Increment 500: Rp9.250 rounds up to Rp9.500 (+250)', () {
        final result = calculator.calculate(
          amount: 9250,
          mode: CashRoundingMode.roundUp,
          increment: 500,
        );
        expect(result.roundedAmount, equals(9500));
        expect(result.roundingAmount, equals(250));
      });
    });

    group('Edge Cases & Disabled', () {
      test('Exact multiple does not change amount', () {
        final result = calculator.calculate(
          amount: 10000,
          mode: CashRoundingMode.roundNearest,
          increment: 500,
        );
        expect(result.roundedAmount, equals(10000));
        expect(result.roundingAmount, equals(0));
      });

      test('Disabled rounding keeps original amount', () {
        final result = calculator.calculate(
          amount: 9997,
          mode: CashRoundingMode.roundNearest,
          increment: 1000,
          enabled: false,
        );
        expect(result.roundedAmount, equals(9997));
        expect(result.roundingAmount, equals(0));
      });

      test('Zero or negative amount is unchanged', () {
        final zero = calculator.calculate(
          amount: 0,
          mode: CashRoundingMode.roundNearest,
          increment: 500,
        );
        expect(zero.roundedAmount, equals(0));
        expect(zero.roundingAmount, equals(0));
      });

      test('Non-cash payment types (QRIS, TRANSFER, CARD) strictly return zero rounding', () {
        for (final nonCash in ['QRIS', 'TRANSFER', 'CARD', 'DEBIT', 'CREDIT']) {
          final res = calculator.calculate(
            amount: 9997,
            mode: CashRoundingMode.roundNearest,
            increment: 1000,
            paymentType: nonCash,
          );
          expect(res.roundedAmount, equals(9997), reason: 'Failed for $nonCash');
          expect(res.roundingAmount, equals(0), reason: 'Failed for $nonCash');
        }
      });
    });
  });
}
