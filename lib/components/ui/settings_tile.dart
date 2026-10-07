import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// Titled group of [SettingsTile]s inside one card, separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(title!.toUpperCase(), style: context.text.overline),
          ),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 60, color: c.divider),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = destructive ? c.error : c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: destructive ? c.errorSoft : c.surfaceSunken,
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, size: 18, color: destructive ? c.error : c.textSecondary),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.bodyStrong.copyWith(color: fg)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: context.text.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron && onTap != null && !destructive)
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
