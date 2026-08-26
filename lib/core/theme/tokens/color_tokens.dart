import 'package:flutter/material.dart';

/// The single source of truth for IrriKart's colour palette.
///
/// **This is the one file to edit when the brand palette changes.** Nothing
/// else in the app should declare a raw [Color]; everything resolves through
/// here, [AppTheme], or `context.colors`.
///
/// [primary] and [secondary] are sampled directly from the client's existing
/// corporate mark (My Irigacio World — a green + blue droplet logo), pixel
///-picked from the source PNG so this is their real brand green and blue, not
/// an approximation. [tertiary] is an olive accent borrowed from the
/// "Botanical Classic" reference theme, reserved for organic/eco badging so
/// it reads as a deliberate accent rather than competing with the primary.
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------

  /// Client brand green, sampled from their droplet logo (#67BD50).
  /// Buttons, active states, selected tabs, primary CTAs.
  static const Color primary = Color(0xFF67BD50);
  static const Color primaryDark = Color(0xFF4A9C37);
  static const Color primaryLight = Color(0xFF8ACD78);

  /// Tonal ramp, used for tinted surfaces and the MaterialColor swatch.
  static const MaterialColor primarySwatch = MaterialColor(0xFF67BD50, {
    50: Color(0xFFEEF8EB),
    100: Color(0xFFD5EDCD),
    200: Color(0xFFB8E0AC),
    300: Color(0xFF9AD388),
    400: Color(0xFF83C96C),
    500: Color(0xFF67BD50),
    600: Color(0xFF5CAB47),
    700: Color(0xFF4E953C),
    800: Color(0xFF418032),
    900: Color(0xFF2C5E20),
  });

  /// Client brand blue, sampled from their droplet logo (#00AFEF). Water /
  /// hydration motifs, links, secondary CTAs, informational accents.
  static const Color secondary = Color(0xFF00AFEF);
  static const Color secondaryDark = Color(0xFF0089BC);
  static const Color secondaryLight = Color(0xFF4FCBFA);

  /// Reference-theme olive, reserved for "organic"/eco badges only — kept
  /// distinct from [primary] so it never competes with the main brand green.
  static const Color tertiary = Color(0xFF71A600);
  static const Color tertiaryDark = Color(0xFF5C8800);

  /// Legacy alias — the theme layer historically called this `accent`.
  static const Color accent = secondary;
  static const Color accentDark = secondaryDark;

  // ---------------------------------------------------------------------
  // Neutrals
  // ---------------------------------------------------------------------

  static const Color black = Color(0xFF14171A);
  static const Color black80 = Color(0xFF43464A);
  static const Color black60 = Color(0xFF72757A);
  static const Color black40 = Color(0xFFA1A3A6);
  static const Color black20 = Color(0xFFD0D1D3);
  static const Color black10 = Color(0xFFE7E8E9);
  static const Color black5 = Color(0xFFF3F3F4);

  static const Color white = Color(0xFFFFFFFF);
  static const Color white80 = Color(0xFFCCCCCC);
  static const Color white60 = Color(0xFF999999);
  static const Color white40 = Color(0xFF666666);
  static const Color white20 = Color(0xFF333333);
  static const Color white10 = Color(0xFF191919);
  static const Color white5 = Color(0xFF0D0D0D);

  static const Color grey = Color(0xFFB5B8B6);
  static const Color greyLight = Color(0xFFF7F8F7);
  static const Color greyDark = Color(0xFF1B1F1C);

  // ---------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF7F8F7);

  static const Color darkBackground = Color(0xFF0F1311);
  static const Color darkSurface = Color(0xFF161B18);
  static const Color darkSurfaceVariant = Color(0xFF1E2521);

  // ---------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // ---------------------------------------------------------------------
  // Domain — stock, vendor, ordering. Exposed via AppColorsExt.
  // ---------------------------------------------------------------------

  static const Color inStock = success;
  static const Color lowStock = warning;
  static const Color outOfStock = Color(0xFF9CA3AF);
  static const Color vendorBadge = Color(0xFF0F766E);
  static const Color rfqBadge = tertiary;
  static const Color codBadge = Color(0xFF7C3AED);
  static const Color organicBadge = tertiary;
}
