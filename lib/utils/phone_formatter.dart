import 'package:flutter/services.dart';

/// Utility class for formatting and validating US phone numbers
/// Format: 555.555.5555 (10 digits, no country code)
class PhoneFormatter {
  PhoneFormatter._();

  /// Format a phone number to 555.555.5555 format
  /// Returns null if input is null or empty
  /// Strips all non-digit characters and formats
  static String? format(String? input) {
    if (input == null || input.isEmpty) return null;

    // Strip all non-digit characters
    final digits = input.replaceAll(RegExp(r'\D'), '');

    // Must be exactly 10 digits
    if (digits.length != 10) return null;

    // Format as 555.555.5555
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
  }

  /// Validate phone number input
  /// Returns error message if invalid, null if valid
  static String? validate(String? input) {
    if (input == null || input.isEmpty) {
      return null; // Optional field
    }

    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 10) {
      return 'Phone number must be 10 digits';
    }

    return null; // Valid
  }

  /// TextInputFormatter for live phone number formatting
  /// As user types, automatically formats to 555.555.5555
  static TextInputFormatter get inputFormatter {
    return _PhoneInputFormatter();
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Strip all non-digit characters
    final digits = text.replaceAll(RegExp(r'\D'), '');

    // Limit to 10 digits
    if (digits.length > 10) {
      return oldValue;
    }

    // Format the digits
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) {
        formatted += '.';
      }
      formatted += digits[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
