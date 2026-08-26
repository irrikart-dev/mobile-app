import 'package:flutter/material.dart';

/// Font families and the text scale.
///
/// Matched to the "Botanical Classic" reference theme's pairing: a bold
/// geometric heading face, a plain-set body face, and a script "kicker" used
/// as a small eyebrow label above section headings (see [scriptFont] and
/// `AppKicker` in `shared/widgets`).
///
/// Every style below sets an explicit [TextStyle.height] rather than
/// trusting Poppins/Open Sans's built-in leading — the built-in metrics run
/// noticeably taller than the raw font size suggests, which is what made
/// fixed-height product cards overflow. Explicit, tight line-heights are
/// what make a layout's own spacing budget trustworthy.
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
    final muted = onSurface.withValues(alpha: 0.62);

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.18,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.24,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.28,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: headingFont,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: headingFont,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
        height: 1.3,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 15,
        height: 1.5,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 13.5,
        height: 1.42,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        height: 1.35,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.2,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.2,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
        color: muted,
      ),
    );
  }

  /// The recurring "kicker" style: a script eyebrow line above a heading.
  static TextStyle kicker(Color color) => TextStyle(
        fontFamily: scriptFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.1,
      );

  /// A price, set in the heading face with tight, non-negative tracking so
  /// digits sit close together the way price tags read in print. Use for
  /// any rupee amount that needs emphasis (product cards, totals).
  static TextStyle price(Color color, {double fontSize = 16}) => TextStyle(
        fontFamily: headingFont,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        color: color,
      );

  /// A struck-through MRP shown next to [price] — same metrics, muted and
  /// unbolded so it recedes rather than competing.
  static TextStyle strikePrice(Color color, {double fontSize = 12}) =>
      TextStyle(
        fontFamily: bodyFont,
        fontSize: fontSize,
        height: 1.2,
        color: color,
        decoration: TextDecoration.lineThrough,
        decorationColor: color,
      );

  /// Small uppercase badge/pill text (discount tags, stock pills).
  static TextStyle overline(Color color, {double fontSize = 10}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.2,
        color: color,
      );
}
