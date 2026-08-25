import 'package:flutter/material.dart';

/// The single source of truth for IrriKart's colour palette.
///
/// **This is the one file to edit when the client's real brand palette
/// arrives.** Nothing else in the app should declare a raw [Color]; everything
/// resolves through here, [AppTheme], or `context.colors`.
///
/// The greens below are a considered placeholder — an agricultural leaf green
/// with an earthy amber accent — chosen so the app reads as agri rather than
/// the upstream template's purple.
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------

  /// Primary brand green. Buttons, active states, selected tabs.
  static const Color primary = Color(0xFF1F7A3D);
  static const Color primaryDark = Color(0xFF15602E);
  static const Color primaryLight = Color(0xFF43A05C);

  /// Tonal ramp, used for tinted surfaces and the MaterialColor swatch.
  static const MaterialColor primarySwatch = MaterialColor(0xFF1F7A3D, {
    50: Color(0xFFE8F4EC),
    100: Color(0xFFC6E4D0),
    200: Color(0xFF9FD2B2),
    300: Color(0xFF78C093),
    400: Color(0xFF5BB37C),
    500: Color(0xFF1F7A3D),
    600: Color(0xFF1B6F37),
    700: Color(0xFF16612F),
    800: Color(0xFF125327),
    900: Color(0xFF0A3B1A),
  });

  /// Harvest amber. Offers, ratings, "bulk enquiry" accents.
  static const Color accent = Color(0xFFE8A33D);
  static const Color accentDark = Color(0xFFC5842A);

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
  static const Color rfqBadge = accent;
  static const Color codBadge = Color(0xFF7C3AED);
}
