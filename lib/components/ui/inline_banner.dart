import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'badges.dart';

/// Tinted inline message — errors under a form, stock warnings in the cart,
/// the offline notice on Home, payment status on an order.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = Tone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final Tone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _defaultIcon => switch (tone) {
        Tone.error => Icons.error_outline_rounded,
        Tone.warning => Icons.warning_amber_rounded,
        Tone.success => Icons.check_circle_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.resolve(context);
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.smd,
        AppSpacing.smd,
        AppSpacing.smd,
        AppSpacing.smd,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon, size: 20, color: fg),
          const SizedBox(width: AppSpacing.smd - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: context.text.label.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: context.text.caption.copyWith(
                    color: title == null ? c.textPrimary : c.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: context.text.label.copyWith(color: fg),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
