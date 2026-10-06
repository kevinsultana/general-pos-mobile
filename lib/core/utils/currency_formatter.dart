import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(num amount) {
    return _formatter.format(amount);
  }

  /// Pembulatan ke atas (Math.ceil) untuk pecahan bila diperlukan
  static int ceilToHundreds(num amount) {
    return (amount / 100).ceil() * 100;
  }
}
