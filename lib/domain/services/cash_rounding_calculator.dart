enum CashRoundingMode {
  roundNearest,
  roundDown,
  roundUp;

  static CashRoundingMode fromString(String mode) {
    switch (mode) {
      case 'ROUND_DOWN':
        return CashRoundingMode.roundDown;
      case 'ROUND_UP':
        return CashRoundingMode.roundUp;
      case 'ROUND_NEAREST':
      default:
        return CashRoundingMode.roundNearest;
    }
  }
}

class CashRoundingResult {
  final int originalAmount;
  final int roundedAmount;
  final int roundingAmount; // roundedAmount - originalAmount

  const CashRoundingResult({
    required this.originalAmount,
    required this.roundedAmount,
    required this.roundingAmount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashRoundingResult &&
          runtimeType == other.runtimeType &&
          originalAmount == other.originalAmount &&
          roundedAmount == other.roundedAmount &&
          roundingAmount == other.roundingAmount;

  @override
  int get hashCode =>
      originalAmount.hashCode ^ roundedAmount.hashCode ^ roundingAmount.hashCode;

  @override
  String toString() =>
      'CashRoundingResult(original: $originalAmount, rounded: $roundedAmount, diff: $roundingAmount)';
}

class CashRoundingCalculator {
  const CashRoundingCalculator();

  CashRoundingResult calculate({
    required int amount,
    required CashRoundingMode mode,
    required int increment,
    bool enabled = true,
    String paymentType = 'CASH',
  }) {
    // PRD Bab 21 & INV-013: Cash rounding only applies to CASH payments
    if (paymentType != 'CASH' || !enabled || increment <= 1 || amount <= 0) {
      return CashRoundingResult(
        originalAmount: amount,
        roundedAmount: amount,
        roundingAmount: 0,
      );
    }

    final int rounded;
    final int remainder = amount % increment;

    if (remainder == 0) {
      return CashRoundingResult(
        originalAmount: amount,
        roundedAmount: amount,
        roundingAmount: 0,
      );
    }

    switch (mode) {
      case CashRoundingMode.roundDown:
        rounded = amount - remainder;
        break;

      case CashRoundingMode.roundUp:
        rounded = amount + (increment - remainder);
        break;

      case CashRoundingMode.roundNearest:
        // Half-up rounding
        if (remainder >= increment / 2) {
          rounded = amount + (increment - remainder);
        } else {
          rounded = amount - remainder;
        }
        break;
    }

    return CashRoundingResult(
      originalAmount: amount,
      roundedAmount: rounded,
      roundingAmount: rounded - amount,
    );
  }
}
