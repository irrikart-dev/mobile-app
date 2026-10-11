import 'package:flutter/services.dart';

/// Pure input rules for the sign-in forms, kept out of the widgets so they
/// can be unit-tested and shared (sign-in, "Your details", the Account tab).
abstract final class AuthValidators {
  static final _indianMobile = RegExp(r'^[6-9]\d{9}$');
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static const minPasswordLength = 8;
  static const maxNameLength = 100;

  /// The bare 10-digit Indian mobile number in [raw] — tolerates spaces,
  /// dashes, a `+91`/`91` country code or a trunk `0` — or null if it isn't
  /// one (must be 10 digits starting 6–9).
  static String? indianMobileDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _indianMobile.hasMatch(digits) ? digits : null;
  }

  static String? phoneError(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter your mobile number';
    if (digits.length != 10) return 'Enter all 10 digits of your number';
    if (indianMobileDigits(digits) == null) {
      return 'Indian mobile numbers start with 6, 7, 8 or 9';
    }
    return null;
  }

  /// `9876543210` → `+919876543210`.
  static String toE164(String tenDigits) => '+91$tenDigits';

  /// `+919876543210` (or `9876543210`) → `+91 98765 43210`. Anything that
  /// isn't an Indian mobile number comes back unchanged.
  static String formatPhone(String phone) {
    final digits = indianMobileDigits(phone);
    if (digits == null) return phone;
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  static String? emailError(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Sign-in only checks presence — the account's real rules were applied
  /// when it was created.
  static String? passwordPresentError(String? raw) =>
      (raw ?? '').isEmpty ? 'Enter your password' : null;

  static String? newPasswordError(String? raw) {
    final v = raw ?? '';
    if (v.isEmpty) return 'Choose a password';
    if (v.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }

  static String? confirmPasswordError(String? raw, String password) {
    if ((raw ?? '').isEmpty) return 'Re-enter your password';
    if (raw != password) return 'Passwords don’t match';
    return null;
  }

  /// Display name as the backend accepts it: trimmed, 1–100 characters.
  /// [optional] lets an empty value through (sign-up).
  static String? nameError(String? raw, {bool optional = false}) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return optional ? null : 'Enter your name';
    if (v.length > maxNameLength) {
      return 'Name must be $maxNameLength characters or fewer';
    }
    return null;
  }
}

/// Keeps the mobile-number field to the 10 national digits, even when a
/// whole `+91 98765 43210` is pasted in.
class IndianMobileInputFormatter extends TextInputFormatter {
  const IndianMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      if (digits.startsWith('91') && digits.length == 12) {
        digits = digits.substring(2);
      } else if (digits.startsWith('0') && digits.length == 11) {
        digits = digits.substring(1);
      } else {
        digits = digits.substring(0, 10);
      }
    }
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
