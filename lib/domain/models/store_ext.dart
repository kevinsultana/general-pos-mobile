import 'dart:convert';
import '../../data/local/app_database.dart';

extension StoreOrderTypeExt on Store {
  /// Returns parsed list of configured order types for this store.
  /// Falls back to default options if unconfigured or corrupt.
  List<String> get orderTypesList {
    try {
      final decoded = jsonDecode(orderTypesJson);
      if (decoded is List) {
        final list = decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return const ['Dine In', 'Takeaway', 'Delivery', 'Online'];
  }
}
