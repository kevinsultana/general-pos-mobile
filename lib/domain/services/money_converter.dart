import '../../core/constants/scale_constants.dart';
import '../../core/utils/currency_formatter.dart';

/// Helper for converting between scaled integers and fractional values
/// for money and stock quantities.
///
/// Mobile stores money as integers in IDR (Rp 15.000 = 15000)
/// Mobile stores stock ledger as integers scaled by 1000 (15.000 units = 15000)
class MoneyConverter {
  MoneyConverter._();

  /// Convert money from scaled integer to display value.
  /// Example: fromMoney(15000) -> 15000.0
  static double fromMoney(int scaled) => fromScaled(scaled, moneyScale);

  /// Convert money from display value to scaled integer.
  /// Example: toMoney(15000.0) -> 15000
  static int toMoney(double value) => toScaled(value, moneyScale);

  /// Formats scaled money integer to localized Rupiah string.
  /// Example: formatRupiahFromScaled(15000) -> "Rp 15.000"
  static String formatRupiahFromScaled(int scaled) {
    return CurrencyFormatter.format(fromMoney(scaled));
  }

  /// Convert stock from scaled integer to unit double value.
  /// Example: fromStock(15000) -> 15.0
  static double fromStock(int scaled) => fromScaled(scaled, stockScale);

  /// Convert stock from unit double value to scaled integer.
  /// Example: toStock(15.0) -> 15000
  static int toStock(double value) => toScaled(value, stockScale);

  /// Formats scaled stock quantity to user-friendly unit string.
  /// Example: formatStock(15000) -> "15", formatStock(15500) -> "15.5"
  static String formatStock(int scaled) {
    final units = fromStock(scaled);
    return units.truncateToDouble() == units
        ? units.toInt().toString()
        : units.toString();
  }
}