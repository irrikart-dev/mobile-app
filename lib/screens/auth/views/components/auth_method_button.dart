import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Neutral, outlined pill for an alternative sign-in method ("Continue with
/// Google", "Continue with email") — sits under the primary phone path.
///
/// With [onPressed] null it renders disabled; taps then fall through to any
/// ancestor `GestureDetector` (the sign-in screen uses that to point at the
/// Terms checkbox).
class AuthMethodButton extends StatelessWidget {
  const AuthMethodButton({
    super.key,
    required this.leading,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final Widget leading;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: enabled && !busy ? onPressed : null,
        behavior: HitTestBehavior.deferToChild,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: AppDurations.fast,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppRadius.pillAll,
              border: Border.all(color: c.borderStrong),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: c.textMuted,
                    ),
                  )
                else ...[
                  SizedBox.square(dimension: 20, child: Center(child: leading)),
                  const SizedBox(width: AppSpacing.smd),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.button.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
