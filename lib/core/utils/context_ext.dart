import 'package:flutter/material.dart';

import '../theme/app_colors_extension.dart';
import '../theme/app_text.dart';

/// Shorthands for the design system:
///
/// ```dart
/// color: context.colors.textSecondary,
/// style: context.text.h2,
/// ```
extension DesignContext on BuildContext {
  AppColorsExt get colors =>
      Theme.of(this).extension<AppColorsExt>() ?? AppColorsExt.light;

  AppText get text => AppText(colors);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// System bottom inset + nav bar clearance, for scrollables in the tab shell.
  double get bottomInset => MediaQuery.paddingOf(this).bottom;
}
