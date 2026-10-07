import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// Soft sage block — the one "container" in the visual language. No border,
/// no shadow: it groups content by tint alone. Tappable when [onTap] is set.
///
/// Use it sparingly (a summary, a promo, a highlighted fact). Lists and
/// sections should sit directly on the canvas, separated by whitespace and
/// dividers — see [Section].
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.margin,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lgAll,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Defaults to `context.colors.tint`.
  final Color? color;

  /// Only for selected/outlined states (e.g. a chosen address).
  final Color? borderColor;
  final BorderRadius radius;

  /// Floating elements only (sticky bars, overlapping sheets).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? c.tint,
        borderRadius: radius,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.5),
        boxShadow: elevated ? c.shadowRaised : null,
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

/// Un-boxed content section: title row (optional trailing action) and the
/// content beneath, sitting on the canvas. Stack sections with
/// [SectionDivider] between them.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.gutter,
      vertical: AppSpacing.mdPlus,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.h3),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Full-bleed 8px tinted band between [Section]s — reads as a page break
/// without drawing a box around anything.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.thin = false});

  /// A 1px hairline with gutter insets instead of the band.
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return thin
        ? Divider(
            height: 1,
            indent: AppSpacing.gutter,
            endIndent: AppSpacing.gutter,
            color: c.divider,
          )
        : Container(height: 8, color: c.surfaceSunken);
  }
}

/// Kept for call sites that still use the boxed API: renders a borderless
/// tinted block with a title row.
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
