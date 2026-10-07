import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// A shimmering placeholder block — a looping gradient sweep over a flat
/// tinted box. Self-contained (no `shimmer` package).
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.height,
    this.width,
    this.borderRadius,
  });

  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.surfaceSunken;
    final highlight = Color.lerp(base, context.isDark ? c.borderStrong : c.surface, 0.9)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1 - 2 * t, 0),
              end: Alignment(2 - 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: widget.borderRadius ?? AppRadius.smAll,
        ),
      ),
    );
  }
}

/// Generic list-row skeleton: square thumb + two text lines.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.thumb = 64});

  final double thumb;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShimmerBox(height: thumb, width: thumb, borderRadius: AppRadius.mdAll),
        const SizedBox(width: AppSpacing.smd),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 14, width: 170),
              SizedBox(height: 8),
              ShimmerBox(height: 12, width: 100),
              SizedBox(height: 8),
              ShimmerBox(height: 14, width: 64),
            ],
          ),
        ),
      ],
    );
  }
}

/// A padded list of [ListRowSkeleton]s inside cards.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 5, this.thumb = 64});

  final int itemCount;
  final double thumb;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.smd),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: c.border),
        ),
        child: ListRowSkeleton(thumb: thumb),
      ),
    );
  }
}
