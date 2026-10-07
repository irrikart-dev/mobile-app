import 'package:flutter/material.dart';

import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'app_button.dart';
import 'badges.dart';

/// Yes/no confirmation. Resolves `true` only on the confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: destructive ? c.errorSoft : c.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: destructive ? c.error : c.onPrimarySoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(title, style: ctx.text.h3),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: ctx.text.bodySecondary),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      label: cancelLabel,
                      size: AppButtonSize.md,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: AppButton(
                      label: confirmLabel,
                      size: AppButtonSize.md,
                      variant: destructive
                          ? AppButtonVariant.destructive
                          : AppButtonVariant.primary,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Consistent snackbars. Clears any visible one first so rapid actions
/// don't queue a backlog.
abstract final class AppSnack {
  static void show(
    BuildContext context,
    String message, {
    Tone tone = Tone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final c = context.colors;
    final iconColor = switch (tone) {
      Tone.success => c.success,
      Tone.error => c.error,
      Tone.warning => c.warning,
      _ => null,
    };
    final icon = switch (tone) {
      Tone.success => Icons.check_circle_rounded,
      Tone.error => Icons.error_rounded,
      Tone.warning => Icons.warning_rounded,
      _ => null,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: AppSpacing.smd),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, tone: Tone.success);

  static void error(BuildContext context, String message) =>
      show(context, message, tone: Tone.error);
}
