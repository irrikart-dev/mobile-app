import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';

/// A shimmering placeholder block — a looping gradient sweep over a flat
/// tinted box. Self-contained (no `shimmer` package) since this is the only
/// place in the app that needs the effect.
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
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.10);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1 - 2 * t, 0),
              end: Alignment(1 - 2 * t + 1, 0),
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

/// Loading placeholder for a catalogue grid — matches `CatalogProductCard`'s
/// proportions so the skeleton-to-real-content swap doesn't visibly jump.
class CatalogGridSkeleton extends StatelessWidget {
  const CatalogGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.60,
      ),
      itemBuilder: (context, i) => const _CardSkeleton(),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(aspectRatio: 1, child: ShimmerBox()),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 14, width: 110),
                SizedBox(height: 6),
                ShimmerBox(height: 11, width: 70),
                SizedBox(height: 6),
                ShimmerBox(height: 14, width: 60),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: ShimmerBox(height: 34),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for the Home screen — mirrors its actual layout
/// (search bar, banner, category row, two horizontal product rails) instead
/// of a generic grid, so the skeleton sits exactly where each real component
/// lands rather than reading as one undifferentiated wash across the screen.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: ShimmerBox(height: 48),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: ShimmerBox(height: 152, borderRadius: AppRadius.lgAll),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: ShimmerBox(height: 18, width: 140),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.smd),
            itemBuilder: (context, i) => const Column(
              children: [
                ShimmerBox(height: 64, width: 64, borderRadius: AppRadius.pillAll),
                SizedBox(height: 8),
                ShimmerBox(height: 10, width: 52),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var rail = 0; rail < 2; rail++) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ShimmerBox(height: 18, width: 160),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  const SizedBox(width: 168, child: _CardSkeleton()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// Loading placeholder for the cart's line-item list.
class CartLinesSkeleton extends StatelessWidget {
  const CartLinesSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => Row(
        children: [
          ShimmerBox(
            height: 72,
            width: 72,
            borderRadius: AppRadius.mdAll,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 14, width: 160),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
