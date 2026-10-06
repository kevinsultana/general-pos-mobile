import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String v4() {
    return _uuid.v4();
  }

  static String receiptNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyMMddHHmmss').format(now);
    final randomSuffix = _uuid.v4().substring(0, 4).toUpperCase();
    return 'TRX-$dateStr-$randomSuffix';
  }
}
