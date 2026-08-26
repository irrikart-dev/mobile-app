import 'package:flutter/material.dart';

/// Font families and the text scale.
///
/// Matched to the "Botanical Classic" reference theme's pairing: a bold
/// geometric heading face, a plain-set body face, and a script "kicker" used
/// as a small eyebrow label above section headings (see [scriptFont] and
/// `AppKicker` in `shared/widgets`).
abstract final class AppTypography {
  /// Headings, prices, section titles.
  static const String headingFont = 'Poppins';

  /// Body and UI copy.
  static const String bodyFont = 'Open Sans';

  /// Small eyebrow label above a heading (e.g. "Fresh from the field").
  /// Reference theme uses a licensed script face ("Shabrina"); Caveat is the
  /// closest unencumbered equivalent.
  static const String scriptFont = 'Caveat';

  static TextTheme textTheme(Color onSurface) {
    final muted = onSurface.withValues(alpha: 0.64);

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.15,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: headingFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        height: 1.45,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        height: 1.4,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }

  /// The recurring "kicker" style: a script eyebrow line above a heading.
  static TextStyle kicker(Color color) => TextStyle(
        fontFamily: scriptFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1,
      );
}
