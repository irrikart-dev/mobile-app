import 'package:flutter/material.dart';

import '../../core/network/api_envelope.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'app_button.dart';

/// Turns any thrown error into one short, human sentence. Backend messages
/// are already user-safe (except 5xx); everything else gets a generic line.
String friendlyError(Object? error) {
  if (error is AuthRequiredException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (error is ApiException) {
    if (error.statusCode == null) {
      return 'You appear to be offline. Check your connection and try again.';
    }
    if (error.isServerError) {
      return 'Our servers are having a moment. Please try again shortly.';
    }
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

/// Centered icon + title + message + optional action. The base for empty,
/// error and success states so they all share proportions.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.iconColor,
    this.iconBackground,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color? iconColor;
  final Color? iconBackground;

  /// Smaller icon and spacing, for states inside a section rather than a page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = compact ? 64.0 : 88.0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: iconBackground ?? c.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: circle * 0.44,
                  color: iconColor ?? c.onPrimarySoft,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? context.text.h3 : context.text.h2,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySecondary,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  size: compact ? AppButtonSize.md : AppButtonSize.lg,
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: AppSpacing.xs),
                AppButton.ghost(label: secondaryLabel!, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) => StateView(
        icon: icon,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        compact: compact,
      );
}

/// Error with a Retry. Pass the raw [error]; it's mapped through
/// [friendlyError], or give an explicit [message].
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.error,
    this.message,
    this.title,
    this.onRetry,
    this.compact = false,
  });

  final Object? error;
  final String? message;
  final String? title;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final offline = error is ApiException && (error as ApiException).statusCode == null;
    return StateView(
      icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
      iconColor: c.error,
      iconBackground: c.errorSoft,
      title: title ?? (offline ? 'You’re offline' : 'Couldn’t load this'),
      message: message ?? friendlyError(error),
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      compact: compact,
    );
  }
}

class SuccessState extends StatelessWidget {
  const SuccessState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StateView(
      icon: Icons.check_rounded,
      iconColor: c.success,
      iconBackground: c.successSoft,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    );
  }
}
