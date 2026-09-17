import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter that automatically inserts thousand separators (dots in Indonesian locale)
/// as the user types, and provides static methods for formatting and parsing.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  /// Formats an integer into a localized thousand-separated string (e.g., 10000 -> "10.000").
  static String format(int value) {
    return _formatter.format(value);
  }

  /// Parses a thousand-separated or raw numeric string back into an integer.
  /// Returns 0 if empty or unparseable.
  static int parse(String text) {
    if (text.isEmpty) return 0;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return 0;
    return int.tryParse(digitsOnly) ?? 0;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Strip everything that is not a digit
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number);

    // Calculate cursor position by counting digits preceding the cursor in the new text
    final cursorIndex = newValue.selection.end;
    final clampedCursor = cursorIndex.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, clampedCursor)
        .replaceAll(RegExp(r'[^\d]'), '')
        .length;

    var newCursorPosition = 0;
    var digitsCounted = 0;

    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitsCounted++;
      }
      if (digitsCounted == digitsBeforeCursor) {
        newCursorPosition = i + 1;
        break;
      }
    }

    if (digitsBeforeCursor == 0) {
      newCursorPosition = 0;
    } else if (digitsCounted < digitsBeforeCursor) {
      newCursorPosition = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursorPosition.clamp(0, formatted.length),
      ),
    );
  }
}
