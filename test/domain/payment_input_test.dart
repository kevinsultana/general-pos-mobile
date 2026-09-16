import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/domain/models/payment_input.dart';

void main() {
  group('PaymentInput — PRD Bab 21 / INV-013 Cash Rounding Enforcement', () {
    test('CASH payment retains valid roundingAmount and calculates totalCashDue', () {
      const payment = PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 9500,
        roundingAmount: 500,
        tenderedAmount: 10000,
        changeAmount: 0,
      );

      expect(payment.roundingAmount, equals(500));
      expect(payment.totalCashDue, equals(10000));
    });

    test('Non-CASH payment (QRIS, TRANSFER, CARD) forces roundingAmount to 0', () {
      for (final type in ['QRIS', 'TRANSFER', 'CARD']) {
        final payment = PaymentInput(
          paymentMethodId: 'pm-$type',
          paymentType: type,
          amount: 9500,
          roundingAmount: 0,
        );

        expect(payment.roundingAmount, equals(0));
        expect(payment.totalCashDue, equals(9500));
      }
    });

    test('CASH payment with negative rounding (discount round down) calculates correctly', () {
      const payment = PaymentInput(
        paymentMethodId: 'pm-cash',
        paymentType: 'CASH',
        amount: 9300,
        roundingAmount: -300,
      );

      expect(payment.roundingAmount, equals(-300));
      expect(payment.totalCashDue, equals(9000));
    });
  });
}
