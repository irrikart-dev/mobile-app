import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'badges.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, destructive }

enum AppButtonSize {
  sm(40, 13),
  md(46, 14),
  lg(52, 15);

  const AppButtonSize(this.height, this.fontSize);
  final double height;
  final double fontSize;
}

/// The one button. Variants cover every call site in the app:
///
/// * [AppButtonVariant.primary] — the single main action on a screen.
/// * [AppButtonVariant.secondary] — tonal green, for a second positive action.
/// * [AppButtonVariant.outline] — neutral alternatives ("Continue shopping").
/// * [AppButtonVariant.ghost] — low-emphasis text actions.
/// * [AppButtonVariant.destructive] — log out, delete.
///
/// [expand] fills the available width; leave it false inside a `Row`.
/// [loading] keeps the button's size and colour but swaps the icon for a
/// spinner and swallows taps, so the layout never jumps mid-request.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;

  static void _ignore() {}

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (c.primary, c.textOnPrimary, null),
      AppButtonVariant.secondary => (c.primarySoft, c.onPrimarySoft, null),
      AppButtonVariant.outline => (c.surface, c.textPrimary, c.borderStrong),
      AppButtonVariant.ghost => (Colors.transparent, c.primary, null),
      AppButtonVariant.destructive => (c.errorSoft, c.error, null),
    };

    final enabled = onPressed != null;
    final iconSize = size == AppButtonSize.sm ? 16.0 : 18.0;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, size.height)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 64)),
      fixedSize: expand
          ? WidgetStatePropertyAll(Size.fromHeight(size.height))
          : null,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: variant == AppButtonVariant.ghost
              ? AppSpacing.smd
              : size == AppButtonSize.sm
                  ? AppSpacing.md
                  : AppSpacing.mdPlus,
        ),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: border == null
              ? BorderSide.none
              : BorderSide(color: enabled ? border : c.border),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? (variant == AppButtonVariant.ghost
                ? Colors.transparent
                : c.surfaceSunken)
            : bg,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.textDisabled : fg,
      ),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
      textStyle: WidgetStatePropertyAll(
        context.text.button.copyWith(fontSize: size.fontSize),
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    final leading = loading
        ? SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : icon == null
            ? null
            : Icon(icon, size: iconSize);

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: AppSpacing.sm)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(trailingIcon, size: iconSize),
        ],
      ],
    );

    final button = TextButton(
      onPressed: loading ? (enabled ? _ignore : null) : onPressed,
      style: style,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Square-ish icon button used in top bars and on media. [filled] gives it a
/// surface + hairline border so it reads over images and busy backgrounds.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
    this.badgeCount = 0,
    this.color,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final int badgeCount;
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget glyph = Icon(icon, size: iconSize, color: color ?? c.textPrimary);
    if (badgeCount > 0) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          glyph,
          Positioned(top: -5, right: -7, child: CountBadge(count: badgeCount)),
        ],
      );
    }

    final button = Material(
      color: filled ? c.surface : Colors.transparent,
      shape: CircleBorder(
        side: filled ? BorderSide(color: c.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(dimension: size, child: Center(child: glyph)),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
