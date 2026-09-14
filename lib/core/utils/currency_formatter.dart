import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(num amount) {
    return _rupiahFormat.format(amount);
  }

  static String formatWithSign(num amount) {
    final formatted = _rupiahFormat.format(amount.abs());
    if (amount > 0) {
      return '+$formatted';
    } else if (amount < 0) {
      return '-$formatted';
    }
    return formatted;
  }
}
