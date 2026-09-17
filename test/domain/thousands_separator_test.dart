import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/utils/thousands_separator_input_formatter.dart';

void main() {
  group('ThousandsSeparatorInputFormatter Unit Tests', () {
    test('format formats numbers with dots as thousands separators', () {
      expect(ThousandsSeparatorInputFormatter.format(0), equals('0'));
      expect(ThousandsSeparatorInputFormatter.format(500), equals('500'));
      expect(ThousandsSeparatorInputFormatter.format(1000), equals('1.000'));
      expect(ThousandsSeparatorInputFormatter.format(15000), equals('15.000'));
      expect(ThousandsSeparatorInputFormatter.format(100000), equals('100.000'));
      expect(ThousandsSeparatorInputFormatter.format(1500000), equals('1.500.000'));
    });

    test('parse parses formatted and raw strings into integers', () {
      expect(ThousandsSeparatorInputFormatter.parse(''), equals(0));
      expect(ThousandsSeparatorInputFormatter.parse('0'), equals(0));
      expect(ThousandsSeparatorInputFormatter.parse('1.000'), equals(1000));
      expect(ThousandsSeparatorInputFormatter.parse('15.000'), equals(15000));
      expect(ThousandsSeparatorInputFormatter.parse('1.500.000'), equals(1500000));
      expect(ThousandsSeparatorInputFormatter.parse('Rp 25.000'), equals(25000));
      expect(ThousandsSeparatorInputFormatter.parse('10000'), equals(10000));
    });

    test('formatEditUpdate formats input as user types digits', () {
      final formatter = ThousandsSeparatorInputFormatter();

      // Typing '1'
      var result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(result.text, equals('1'));
      expect(result.selection.end, equals(1));

      // Typing '000' -> '1000' -> becomes '1.000'
      result = formatter.formatEditUpdate(
        const TextEditingValue(text: '100', selection: TextSelection.collapsed(offset: 3)),
        const TextEditingValue(text: '1000', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(result.text, equals('1.000'));
      expect(result.selection.end, equals(5));

      // Typing extra '0' -> '10.000'
      result = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.000', selection: TextSelection.collapsed(offset: 5)),
        const TextEditingValue(text: '1.0000', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(result.text, equals('10.000'));
      expect(result.selection.end, equals(6));
    });
  });
}
