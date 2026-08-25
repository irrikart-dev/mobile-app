import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors_extension.dart';
import 'tokens/color_tokens.dart';
import 'tokens/radius_tokens.dart';
import 'tokens/spacing_tokens.dart';
import 'tokens/typography_tokens.dart';

/// IrriKart's Material themes.
///
/// The upstream template shipped light only — dark mode was behind the
/// paywall. Both are defined here and selected by [ThemeMode.system] unless
/// the user overrides it in preferences.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isLight ? AppColors.primary : AppColors.primaryLight,
      onPrimary: AppColors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.black,
      error: isLight ? AppColors.error : const Color(0xFFF87171),
      surface: isLight ? AppColors.lightSurface : AppColors.darkSurface,
      onSurface: isLight ? AppColors.black : AppColors.white,
    );

    final onSurface = scheme.onSurface;
    final textTheme = AppTypography.textTheme(onSurface);
    final ext = isLight ? AppColorsExt.light : AppColorsExt.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.primaryFont,
      textTheme: textTheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.lightBackground : AppColors.darkBackground,
      extensions: <ThemeExtension<dynamic>>[ext],
      appBarTheme: AppBarTheme(
        backgroundColor:
            isLight ? AppColors.lightBackground : AppColors.darkBackground,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: ext.outOfStock.withValues(alpha: 0.35),
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: ext.divider),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.lightSurfaceVariant
            : AppColors.darkSurfaceVariant,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        hintStyle: textTheme.bodyMedium?.copyWith(color: ext.muted),
        border: _border(ext.divider),
        enabledBorder: _border(ext.divider),
        focusedBorder: _border(scheme.primary, width: 1.4),
        errorBorder: _border(scheme.error),
        focusedErrorBorder: _border(scheme.error, width: 1.4),
      ),
      cardTheme: CardThemeData(
        color: isLight ? AppColors.lightSurface : AppColors.darkSurfaceVariant,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: ext.divider),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? AppColors.lightSurfaceVariant
            : AppColors.darkSurfaceVariant,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        labelStyle: textTheme.bodySmall?.copyWith(color: onSurface),
        side: BorderSide(color: ext.divider),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: ext.muted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isLight ? AppColors.black : AppColors.darkSurfaceVariant,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.white,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      dividerTheme:
          DividerThemeData(color: ext.divider, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        side: BorderSide(color: ext.divider, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(ext.muted.withValues(alpha: 0.4)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isLight ? AppColors.lightSurface : AppColors.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
