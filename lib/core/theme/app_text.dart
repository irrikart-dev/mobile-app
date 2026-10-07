import 'package:flutter/material.dart';

import 'app_colors_extension.dart';
import 'tokens/typography_tokens.dart';

/// Role-based text styles. Read through `context.text`:
///
/// ```dart
/// Text('Cart', style: context.text.h1)
/// Text('2 items', style: context.text.caption)
/// ```
///
/// Each role already carries the right colour for the current theme; use
/// `.copyWith(color: …)` only for genuinely different emphasis.
@immutable
class AppText {
  const AppText(this._c);

  final AppColorsExt _c;

  static const _h = AppTypography.headingFont;
  static const _b = AppTypography.bodyFont;

  /// Hero headlines (onboarding, success screens). 32 / 800.
  TextStyle get display => TextStyle(
        fontFamily: _h,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
        color: _c.textPrimary,
      );

  /// Screen titles. 24 / 700.
  TextStyle get h1 => TextStyle(
        fontFamily: _h,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.22,
        color: _c.textPrimary,
      );

  /// Section titles. 20 / 700.
  TextStyle get h2 => TextStyle(
        fontFamily: _h,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
        color: _c.textPrimary,
      );

  /// Card / sheet titles. 17 / 600.
  TextStyle get h3 => TextStyle(
        fontFamily: _h,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: _c.textPrimary,
      );

  /// List-row titles, product names. 15 / 600.
  TextStyle get title => TextStyle(
        fontFamily: _h,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.32,
        color: _c.textPrimary,
      );

  /// Smaller titles inside dense cards. 13 / 600.
  TextStyle get titleSm => TextStyle(
        fontFamily: _h,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: _c.textPrimary,
      );

  /// Running text. 14 / 400.
  TextStyle get body => TextStyle(
        fontFamily: _b,
        fontSize: 14,
        height: 1.45,
        color: _c.textPrimary,
      );

  /// Emphasised running text. 14 / 600.
  TextStyle get bodyStrong => body.copyWith(fontWeight: FontWeight.w600);

  /// Supporting copy under a title. 14 / 400, secondary.
  TextStyle get bodySecondary => body.copyWith(color: _c.textSecondary);

  /// Metadata, helper text. 12 / 400, secondary.
  TextStyle get caption => TextStyle(
        fontFamily: _b,
        fontSize: 12,
        height: 1.4,
        color: _c.textSecondary,
      );

  /// Captions that should recede further. 12 / 400, muted.
  TextStyle get captionMuted => caption.copyWith(color: _c.textMuted);

  /// Uppercase eyebrow labels. 11 / 700, tracked.
  TextStyle get overline => TextStyle(
        fontFamily: _b,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.2,
        color: _c.textMuted,
      );

  /// Form labels, chip labels. 13 / 600.
  TextStyle get label => TextStyle(
        fontFamily: _b,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: _c.textPrimary,
      );

  /// Button labels. 15 / 600.
  TextStyle get button => const TextStyle(
        fontFamily: _h,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  /// Product-card price. 16 / 700.
  TextStyle get price => TextStyle(
        fontFamily: _h,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        color: _c.textPrimary,
      );

  /// PDP / totals price. 26 / 800.
  TextStyle get priceLarge => TextStyle(
        fontFamily: _h,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.15,
        color: _c.textPrimary,
      );

  /// Struck-through MRP. 13 / 400, muted.
  TextStyle get priceStrike => TextStyle(
        fontFamily: _b,
        fontSize: 13,
        height: 1.2,
        color: _c.textMuted,
        decoration: TextDecoration.lineThrough,
        decorationColor: _c.textMuted,
      );

  /// Badges and pills. 10.5 / 700.
  TextStyle get badge => const TextStyle(
        fontFamily: _b,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.2,
      );
}
