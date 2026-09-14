import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/services/barcode_label_service.dart';

void main() {
  group('BarcodeLabelService Tests', () {
    test('isValidCode128 accepts valid alphanumeric & ASCII strings', () {
      expect(BarcodeLabelService.isValidCode128('PROD-001'), isTrue);
      expect(BarcodeLabelService.isValidCode128('899276100123'), isTrue);
      expect(BarcodeLabelService.isValidCode128('COFFEE-LATTE-12'), isTrue);
    });

    test('isValidCode128 rejects empty or whitespace-only strings', () {
      expect(BarcodeLabelService.isValidCode128(''), isFalse);
      expect(BarcodeLabelService.isValidCode128('   '), isFalse);
    });

    test('generateSvg generates valid XML/SVG with CODE 128 bars', () {
      const data = 'PRD-889922';
      final svg = BarcodeLabelService.generateSvg(data, width: 250, height: 100);

      expect(svg, isNotEmpty);
      expect(svg.contains('<svg'), isTrue);
      expect(svg.contains('</svg>'), isTrue);
      expect(svg.contains(data), isTrue); // Text is embedded
    });

    test('BarcodeLabelData formats displayName correctly with/without variant', () {
      const withVariant = BarcodeLabelData(
        productName: 'Kemeja Flanel',
        variantName: 'Size XL',
        barcodeValue: 'KMJ-XL-001',
        price: 125000,
        storeName: 'Toko Baju Bersama',
      );
      expect(withVariant.displayName, equals('Kemeja Flanel (Size XL)'));

      const withoutVariant = BarcodeLabelData(
        productName: 'Minyak Goreng 2L',
        barcodeValue: '89912345678',
        price: 34000,
        storeName: 'Minimarket Kita',
      );
      expect(withoutVariant.displayName, equals('Minyak Goreng 2L'));
    });
  });
}
