import 'package:flutter/material.dart';

import 'tokens/color_tokens.dart';

/// Colours that carry domain meaning and have no slot in [ColorScheme].
///
/// Reach these through `Theme.of(context).extension<AppColorsExt>()!` or the
/// `context.colors` shorthand in `core/utils/extensions/context_ext.dart`.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.success,
    required this.warning,
    required this.info,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.vendorBadge,
    required this.rfqBadge,
    required this.codBadge,
    required this.discount,
    required this.muted,
    required this.divider,
  });

  final Color success;
  final Color warning;
  final Color info;

  /// Stock states shown on product cards and the variant selector.
  final Color inStock;
  final Color lowStock;
  final Color outOfStock;

  /// Badges: seller attribution, bulk-quote availability, cash on delivery.
  final Color vendorBadge;
  final Color rfqBadge;
  final Color codBadge;

  /// Discount and savings emphasis.
  final Color discount;

  /// Secondary text and hairline rules.
  final Color muted;
  final Color divider;

  static const AppColorsExt light = AppColorsExt(
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    inStock: AppColors.inStock,
    lowStock: AppColors.lowStock,
    outOfStock: AppColors.outOfStock,
    vendorBadge: AppColors.vendorBadge,
    rfqBadge: AppColors.rfqBadge,
    codBadge: AppColors.codBadge,
    discount: AppColors.error,
    muted: AppColors.black60,
    divider: AppColors.black10,
  );

  static const AppColorsExt dark = AppColorsExt(
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
    inStock: Color(0xFF4ADE80),
    lowStock: Color(0xFFFBBF24),
    outOfStock: Color(0xFF6B7280),
    vendorBadge: Color(0xFF2DD4BF),
    rfqBadge: Color(0xFFF3B85C),
    codBadge: Color(0xFFA78BFA),
    discount: Color(0xFFF87171),
    muted: AppColors.white60,
    divider: AppColors.white20,
  );

  @override
  AppColorsExt copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? inStock,
    Color? lowStock,
    Color? outOfStock,
    Color? vendorBadge,
    Color? rfqBadge,
    Color? codBadge,
    Color? discount,
    Color? muted,
    Color? divider,
  }) {
    return AppColorsExt(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      inStock: inStock ?? this.inStock,
      lowStock: lowStock ?? this.lowStock,
      outOfStock: outOfStock ?? this.outOfStock,
      vendorBadge: vendorBadge ?? this.vendorBadge,
      rfqBadge: rfqBadge ?? this.rfqBadge,
      codBadge: codBadge ?? this.codBadge,
      discount: discount ?? this.discount,
      muted: muted ?? this.muted,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      inStock: Color.lerp(inStock, other.inStock, t)!,
      lowStock: Color.lerp(lowStock, other.lowStock, t)!,
      outOfStock: Color.lerp(outOfStock, other.outOfStock, t)!,
      vendorBadge: Color.lerp(vendorBadge, other.vendorBadge, t)!,
      rfqBadge: Color.lerp(rfqBadge, other.rfqBadge, t)!,
      codBadge: Color.lerp(codBadge, other.codBadge, t)!,
      discount: Color.lerp(discount, other.discount, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
