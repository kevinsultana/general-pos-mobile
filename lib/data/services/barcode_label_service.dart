import 'package:barcode/barcode.dart';

class BarcodeLabelData {
  final String productName;
  final String? variantName;
  final String barcodeValue;
  final int price;
  final String storeName;

  const BarcodeLabelData({
    required this.productName,
    this.variantName,
    required this.barcodeValue,
    required this.price,
    required this.storeName,
  });

  String get displayName =>
      variantName != null && variantName!.isNotEmpty
          ? '$productName ($variantName)'
          : productName;
}

class BarcodeLabelService {
  /// Validates if text can be encoded in CODE 128
  static bool isValidCode128(String data) {
    if (data.trim().isEmpty) return false;
    try {
      Barcode.code128().verify(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates SVG representation of CODE 128 barcode
  static String generateSvg(String data, {double width = 200, double height = 80}) {
    final barcode = Barcode.code128();
    return barcode.toSvg(
      data,
      width: width,
      height: height,
      drawText: true,
    );
  }
}
