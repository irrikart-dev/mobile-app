import 'package:flutter/material.dart';

import 'tokens/color_tokens.dart';

/// Every theme-aware colour role the UI uses. Read through `context.colors`
/// (`core/utils/context_ext.dart`). Screens should never reach for raw
/// [AppColors] or `Colors.*` — if a role is missing, add it here.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.tint,
    required this.accent,
    required this.navBar,
    required this.onNavBar,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textOnPrimary,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.primary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.discount,
    required this.rating,
    required this.wishlist,
    required this.scrim,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.vendorBadge,
    required this.rfqBadge,
    required this.shadowCard,
    required this.shadowRaised,
    required this.shadowFloating,
  });

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;

  /// Soft sage behind product images, category tiles and promo blocks —
  /// the main way content is grouped without drawing boxes.
  final Color tint;

  /// The bright brand green (#67BD50) for highlights; [primary] is the deep
  /// forest green used for CTAs and selection.
  final Color accent;

  /// Floating bottom navigation bar background / foreground.
  final Color navBar;
  final Color onNavBar;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textOnPrimary;

  // Lines
  final Color border;
  final Color borderStrong;
  final Color divider;

  // Brand
  final Color primary;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color secondary;
  final Color secondarySoft;

  // Status (solid + tinted background)
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;

  // Commerce
  final Color discount;
  final Color rating;
  final Color wishlist;
  final Color scrim;
  final Color inStock;
  final Color lowStock;
  final Color outOfStock;
  final Color vendorBadge;
  final Color rfqBadge;

  // Elevation — dark mode leans on borders instead of shadows.
  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowRaised;
  final List<BoxShadow> shadowFloating;

  /// Legacy names, kept so not-yet-migrated widgets still compile.
  Color get muted => textMuted;

  static const AppColorsExt light = AppColorsExt(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurface,
    surfaceSunken: AppColors.lightSurfaceVariant,
    tint: AppColors.lightTint,
    accent: AppColors.primary,
    navBar: AppColors.forest,
    onNavBar: AppColors.white,
    textPrimary: AppColors.ink,
    textSecondary: AppColors.inkSecondary,
    textMuted: AppColors.inkMuted,
    textDisabled: AppColors.inkDisabled,
    textOnPrimary: AppColors.white,
    border: AppColors.line,
    borderStrong: AppColors.lineStrong,
    divider: AppColors.lineSoft,
    primary: AppColors.forest,
    primarySoft: Color(0xFFE6F1E0),
    onPrimarySoft: AppColors.forest,
    secondary: AppColors.secondaryDark,
    secondarySoft: Color(0xFFE3F5FC),
    success: AppColors.success,
    successSoft: Color(0xFFE7F6EC),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3E2),
    error: AppColors.error,
    errorSoft: Color(0xFFFDECEC),
    info: AppColors.info,
    infoSoft: Color(0xFFE8EFFD),
    discount: AppColors.success,
    rating: AppColors.rating,
    wishlist: AppColors.rose,
    scrim: Color(0x8A0E1210),
    inStock: AppColors.inStock,
    lowStock: Color(0xFFB45309),
    outOfStock: AppColors.outOfStock,
    vendorBadge: AppColors.vendorBadge,
    rfqBadge: AppColors.rfqBadge,
    shadowCard: [
      BoxShadow(color: Color(0x0F1F5C3A), offset: Offset(0, 8), blurRadius: 24),
    ],
    shadowRaised: [
      BoxShadow(color: Color(0x14141A16), offset: Offset(0, 8), blurRadius: 24),
    ],
    shadowFloating: [
      BoxShadow(color: Color(0x1F141A16), offset: Offset(0, 12), blurRadius: 32),
    ],
  );

  static const AppColorsExt dark = AppColorsExt(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceVariant,
    surfaceSunken: Color(0xFF121714),
    tint: AppColors.darkTint,
    accent: AppColors.primary,
    navBar: Color(0xFF1B241E),
    onNavBar: AppColors.inkDark,
    textPrimary: AppColors.inkDark,
    textSecondary: AppColors.inkSecondaryDark,
    textMuted: AppColors.inkMutedDark,
    textDisabled: AppColors.inkDisabledDark,
    textOnPrimary: AppColors.darkBackground,
    border: AppColors.lineDark,
    borderStrong: AppColors.lineStrongDark,
    divider: AppColors.lineSoftDark,
    primary: AppColors.primary,
    primarySoft: Color(0xFF1C2D18),
    onPrimarySoft: AppColors.primaryLight,
    secondary: AppColors.secondaryLight,
    secondarySoft: Color(0xFF10262F),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF13291B),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF2E2410),
    error: Color(0xFFF87171),
    errorSoft: Color(0xFF331A1A),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF15223A),
    discount: Color(0xFF4ADE80),
    rating: Color(0xFFFBBF24),
    wishlist: Color(0xFFFF6B70),
    scrim: Color(0xB3000000),
    inStock: Color(0xFF4ADE80),
    lowStock: Color(0xFFFBBF24),
    outOfStock: Color(0xFF6B7280),
    vendorBadge: Color(0xFF2DD4BF),
    rfqBadge: Color(0xFFF3B85C),
    shadowCard: [],
    shadowRaised: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 8), blurRadius: 24),
    ],
    shadowFloating: [
      BoxShadow(color: Color(0x80000000), offset: Offset(0, 12), blurRadius: 32),
    ],
  );

  @override
  AppColorsExt copyWith() => this;

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColorsExt(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      tint: l(tint, other.tint),
      accent: l(accent, other.accent),
      navBar: l(navBar, other.navBar),
      onNavBar: l(onNavBar, other.onNavBar),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      textDisabled: l(textDisabled, other.textDisabled),
      textOnPrimary: l(textOnPrimary, other.textOnPrimary),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      divider: l(divider, other.divider),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimarySoft: l(onPrimarySoft, other.onPrimarySoft),
      secondary: l(secondary, other.secondary),
      secondarySoft: l(secondarySoft, other.secondarySoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      error: l(error, other.error),
      errorSoft: l(errorSoft, other.errorSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      discount: l(discount, other.discount),
      rating: l(rating, other.rating),
      wishlist: l(wishlist, other.wishlist),
      scrim: l(scrim, other.scrim),
      inStock: l(inStock, other.inStock),
      lowStock: l(lowStock, other.lowStock),
      outOfStock: l(outOfStock, other.outOfStock),
      vendorBadge: l(vendorBadge, other.vendorBadge),
      rfqBadge: l(rfqBadge, other.rfqBadge),
      shadowCard: t < 0.5 ? shadowCard : other.shadowCard,
      shadowRaised: t < 0.5 ? shadowRaised : other.shadowRaised,
      shadowFloating: t < 0.5 ? shadowFloating : other.shadowFloating,
    );
  }
}
