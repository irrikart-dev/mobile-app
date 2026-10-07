import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

enum Tone { neutral, primary, success, warning, error, info }

extension ToneColors on Tone {
  (Color fg, Color bg) resolve(BuildContext context) {
    final c = context.colors;
    return switch (this) {
      Tone.neutral => (c.textSecondary, c.surfaceSunken),
      Tone.primary => (c.onPrimarySoft, c.primarySoft),
      Tone.success => (c.success, c.successSoft),
      Tone.warning => (c.warning, c.warningSoft),
      Tone.error => (c.error, c.errorSoft),
      Tone.info => (c.info, c.infoSoft),
    };
  }
}

/// Tinted, rounded label — order status, stock state, "Default" address.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = Tone.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  /// Leading status dot instead of an icon.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: context.text.badge.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Small solid label placed over media — "OUT OF STOCK", "NEW", "-20%".
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? c.textPrimary,
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        label,
        style: context.text.badge.copyWith(
          color: foreground ?? c.background,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Round numeric badge (cart count, wishlist count).
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Container(
        key: ValueKey(count),
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c.error,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: c.surface, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: context.text.badge.copyWith(
            color: Colors.white,
            fontSize: 9.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
