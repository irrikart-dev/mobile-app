import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/utils/context_ext.dart';

enum StepperSize {
  sm(32, 16, 28),
  md(40, 18, 36);

  const StepperSize(this.height, this.icon, this.valueWidth);
  final double height;
  final double icon;
  final double valueWidth;
}

/// The one quantity control.
///
/// When [allowRemove] is true and the value is at [min], the minus button
/// becomes a trash icon and emits `min - 1` (i.e. 0) so the caller can drop
/// the line. [max] disables plus; [busy] dims the whole control.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.allowRemove = false,
    this.busy = false,
    this.size = StepperSize.md,
    this.filled = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final bool allowRemove;
  final bool busy;
  final StepperSize size;

  /// Solid primary background (used on product cards once added).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final atMin = value <= min;
    final atMax = max != null && value >= max!;
    final fg = filled ? c.textOnPrimary : c.textPrimary;
    final accent = filled ? c.textOnPrimary : c.primary;

    final canDecrement = !busy && (!atMin || allowRemove);
    final canIncrement = !busy && !atMax;

    void tap(int next) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }

    return AnimatedOpacity(
      opacity: busy ? 0.6 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: size.height,
        decoration: BoxDecoration(
          color: filled ? c.primary : c.surface,
          borderRadius: AppRadius.pillAll,
          border: filled ? null : Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StepButton(
              icon: atMin && allowRemove
                  ? Icons.delete_outline_rounded
                  : Icons.remove_rounded,
              size: size,
              color: canDecrement ? accent : c.textDisabled,
              semantic: atMin && allowRemove ? 'Remove' : 'Decrease quantity',
              onTap: canDecrement ? () => tap(value - 1) : null,
            ),
            SizedBox(
              width: size.valueWidth,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, a) =>
                    FadeTransition(opacity: a, child: child),
                child: Text(
                  '$value',
                  key: ValueKey(value),
                  textAlign: TextAlign.center,
                  style: context.text.title.copyWith(
                    color: fg,
                    fontSize: size == StepperSize.sm ? 13 : 15,
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              size: size,
              color: canIncrement ? accent : c.textDisabled,
              semantic: 'Increase quantity',
              onTap: canIncrement ? () => tap(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.semantic,
    required this.onTap,
  });

  final IconData icon;
  final StepperSize size;
  final Color color;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: InkResponse(
        onTap: onTap,
        radius: size.height / 2,
        child: SizedBox.square(
          dimension: size.height,
          child: Icon(icon, size: size.icon, color: color),
        ),
      ),
    );
  }
}
