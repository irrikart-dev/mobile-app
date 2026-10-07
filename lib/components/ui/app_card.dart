import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// Surface card: white (or dark surface) with a hairline border and the soft
/// card shadow. Tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.margin,
    this.color,
    this.borderColor,
    this.radius = AppRadius.mdAll,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final BorderRadius radius;

  /// Adds the card shadow (light mode only — dark relies on the border).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? c.border),
        boxShadow: elevated ? c.shadowCard : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// Card with a title row (icon + title + optional trailing action) on top.
/// Used for checkout sections and order-detail blocks.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: c.textSecondary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: Text(title, style: context.text.title)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          child,
        ],
      ),
    );
  }
}
