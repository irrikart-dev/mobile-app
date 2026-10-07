import 'package:flutter/material.dart';

/// Font families and the Material text scale.
///
/// One family — Plus Jakarta Sans — for everything; hierarchy comes from
/// weight, size and tracking.
/// Every style sets an explicit [TextStyle.height]: both faces' built-in
/// leading runs tall, and fixed-height cards overflow without it.
///
/// Screens should use the role-based styles in `AppText` (`context.text`),
/// which sit on top of this scale.
abstract final class AppTypography {
  static const String headingFont = 'Plus Jakarta Sans';
  static const String bodyFont = 'Plus Jakarta Sans';

  static TextTheme textTheme(Color onSurface, Color secondary) {
    TextStyle heading(
      double size,
      FontWeight weight,
      double tracking,
      double height,
    ) =>
        TextStyle(
          fontFamily: headingFont,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: height,
          color: onSurface,
        );

    return TextTheme(
      displayLarge: heading(32, FontWeight.w800, -0.8, 1.15),
      displayMedium: heading(28, FontWeight.w700, -0.6, 1.18),
      displaySmall: heading(26, FontWeight.w700, -0.5, 1.2),
      headlineLarge: heading(24, FontWeight.w700, -0.4, 1.22),
      headlineMedium: heading(20, FontWeight.w700, -0.3, 1.25),
      headlineSmall: heading(17, FontWeight.w600, -0.2, 1.3),
      titleLarge: heading(17, FontWeight.w600, -0.2, 1.3),
      titleMedium: heading(15, FontWeight.w600, -0.1, 1.32),
      titleSmall: heading(13, FontWeight.w600, 0, 1.3),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 15,
        height: 1.5,
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
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontFamily: headingFont,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.2,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.25,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
        color: secondary,
      ),
    );
  }

  /// Legacy script eyebrow — rendered in the body face now.
  static TextStyle kicker(Color color) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
        height: 1.2,
      );

  static TextStyle price(Color color, {double fontSize = 16}) => TextStyle(
        fontFamily: headingFont,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        color: color,
      );

  static TextStyle strikePrice(Color color, {double fontSize = 12}) =>
      TextStyle(
        fontFamily: bodyFont,
        fontSize: fontSize,
        height: 1.2,
        color: color,
        decoration: TextDecoration.lineThrough,
        decorationColor: color,
      );

  static TextStyle overline(Color color, {double fontSize = 10}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.2,
        color: color,
      );
}
