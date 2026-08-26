import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';

/// A frosted-glass surface: blurred backdrop, translucent tint, and a
/// hairline highlight border.
///
/// This is the one place glassmorphism is implemented — every other glass
/// widget in the app (app bar, bottom nav, sheets) wraps this rather than
/// reimplementing `BackdropFilter`. Keeping it centralised means the blur
/// intensity and tint can be tuned once for both themes.
///
/// Not used for product/category cards or hero overlays by design — glass is
/// reserved for chrome (navigation) and overlays (sheets/modals), where a
/// transparent surface reads as "floating above content" rather than
/// fighting for attention with product imagery.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.borderRadius,
    this.padding,
    this.tintOpacity = 0.55,
    this.borderOpacity = 0.35,
  });

  final Widget child;

  /// Backdrop blur sigma. Higher reads "frostier"; lower keeps content
  /// beneath more legible. 18 is tuned for text scrolling under a nav bar.
  final double blur;

  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// How opaque the tint layer is over the blur. Kept mid-range so the glass
  /// effect survives both a bright product photo and a plain background.
  final double tintOpacity;

  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppRadius.mdAll;

    final tint = isDark
        ? Color.fromRGBO(20, 24, 22, tintOpacity)
        : Color.fromRGBO(255, 255, 255, tintOpacity);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: borderOpacity * 0.4)
        : Colors.white.withValues(alpha: borderOpacity);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
