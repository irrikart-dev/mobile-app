import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/duration_tokens.dart';
import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// Pill chip for filters, sort and choices (variant sizes, popular
/// searches). [dropdown] adds a caret for chips that open a sheet.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.dropdown = false,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dropdown;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = !enabled
        ? c.textDisabled
        : selected
            ? c.onPrimarySoft
            : c.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: AppRadius.pillAll,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.label.copyWith(
                  color: fg,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                ),
              ),
              if (dropdown) ...[
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling chip row with page-gutter padding.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}
