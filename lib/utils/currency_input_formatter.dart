import 'package:flutter/services.dart';

/// TextInputFormatter for Indonesian Rupiah currency format (e.g., 1.000.000)
/// Automatically adds thousand separators (.) as user types
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new value is empty, return it as-is
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // If no digits, return empty
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Format with thousand separators
    String formatted = _formatWithThousandSeparator(digitsOnly);

    // Calculate new cursor position
    int cursorPosition = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }

  /// Formats a string of digits with thousand separators (dots)
  /// Example: "1000000" becomes "1.000.000"
  String _formatWithThousandSeparator(String digitsOnly) {
    // Parse as integer to remove leading zeros
    int value = int.tryParse(digitsOnly) ?? 0;
    if (value == 0) return '0';

    String valueString = value.toString();
    String result = '';
    int counter = 0;

    // Iterate from right to left
    for (int i = valueString.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) {
        result = '.$result';
      }
      result = valueString[i] + result;
      counter++;
    }

    return result;
  }
}

/// Helper class to parse formatted currency back to double
class CurrencyHelper {
  /// Converts formatted currency string (e.g., "1.000.000") to double
  /// Returns 0.0 if parsing fails
  static double parse(String formatted) {
    if (formatted.isEmpty) return 0.0;
    
    // Remove all dots (thousand separators)
    String digitsOnly = formatted.replaceAll('.', '');
    
    return double.tryParse(digitsOnly) ?? 0.0;
  }

  /// Formats a double value to Indonesian Rupiah format
  /// Example: 1000000.0 becomes "1.000.000"
  static String format(double value) {
    if (value == 0) return '0';
    
    int intValue = value.toInt();
    String valueString = intValue.toString();
    String result = '';
    int counter = 0;

    for (int i = valueString.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) {
        result = '.$result';
      }
      result = valueString[i] + result;
      counter++;
    }

    return result;
  }
}
