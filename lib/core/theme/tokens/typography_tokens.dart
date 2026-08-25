import 'package:flutter/material.dart';

/// Font families and the text scale.
///
/// The template shipped no real [TextTheme] — sizes were declared inline in
/// every widget. This defines the scale once so widgets can stop doing that.
abstract final class AppTypography {
  /// Body and UI copy.
  static const String primaryFont = 'Plus Jakarta';

  /// Display font, used for headings and price emphasis.
  static const String displayFont = 'Grandis Extended';

  static TextTheme textTheme(Color onSurface) {
    final muted = onSurface.withValues(alpha: 0.64);

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: primaryFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        height: 1.45,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        height: 1.4,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: primaryFont,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }
}
