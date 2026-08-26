import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import 'glass_container.dart';

/// Frosted shell for a bottom sheet or modal.
///
/// Pass to [showModalBottomSheet] with `backgroundColor: Colors.transparent`
/// so this widget's own glass surface is what's visible, not the sheet
/// theme's solid fill:
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: Colors.transparent,
///   isScrollControlled: true,
///   builder: (_) => GlassSheet(child: ...),
/// );
/// ```
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.showDragHandle = true,
    this.maxHeightFraction = 0.9,
  });

  final Widget child;
  final bool showDragHandle;

  /// Cap on how tall the sheet may grow, as a fraction of screen height.
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFraction;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassContainer(
          blur: 24,
          tintOpacity: 0.82,
          borderOpacity: 0.3,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
                ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper around [showModalBottomSheet] pre-wired for
/// [GlassSheet]'s transparent-background requirement.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxHeightFraction = 0.9,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => GlassSheet(
      maxHeightFraction: maxHeightFraction,
      child: builder(ctx),
    ),
  );
}
