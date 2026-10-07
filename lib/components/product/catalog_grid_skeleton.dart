import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import '../ui/skeleton.dart';
import 'catalog_product_card.dart';

export '../ui/skeleton.dart' show ShimmerBox;

/// Skeleton matching [CatalogProductCard]'s exact proportions, so the swap
/// to real content doesn't jump.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ShimmerBox(borderRadius: BorderRadius.zero),
          ),
          SizedBox(
            height: kProductCardContentHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 12, width: 120),
                  SizedBox(height: 6),
                  ShimmerBox(height: 12, width: 80),
                  SizedBox(height: 10),
                  ShimmerBox(height: 10, width: 60),
                  Spacer(),
                  ShimmerBox(height: 16, width: 70),
                  SizedBox(height: 10),
                  ShimmerBox(height: 32, borderRadius: AppRadius.pillAll),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sliver grid of [ProductCardSkeleton]s with the real grid's geometry.
class SliverProductGridSkeleton extends StatelessWidget {
  const SliverProductGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width >= 600 ? 3 : 2;
          const spacing = SliverProductGrid.spacing;
          final tile = (width - spacing * (columns - 1)) / columns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: tile + kProductCardContentHeight + 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => const ProductCardSkeleton(),
              childCount: itemCount,
            ),
          );
        },
      ),
    );
  }
}

/// Box version of the grid skeleton for screens that aren't sliver-based.
class CatalogGridSkeleton extends StatelessWidget {
  const CatalogGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverProductGridSkeleton(itemCount: itemCount),
      ],
    );
  }
}

/// Loading placeholder for Home — mirrors its real layout.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: ShimmerBox(height: 168, borderRadius: AppRadius.lgAll),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: ShimmerBox(height: 18, width: 140),
        ),
        const SizedBox(height: AppSpacing.smd),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.smd),
            itemBuilder: (context, i) => const Column(
              children: [
                ShimmerBox(height: 64, width: 64, borderRadius: AppRadius.lgAll),
                SizedBox(height: 8),
                ShimmerBox(height: 10, width: 52),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        for (var rail = 0; rail < 2; rail++) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: ShimmerBox(height: 18, width: 160),
          ),
          const SizedBox(height: AppSpacing.smd),
          SizedBox(
            height: 164 + kProductCardContentHeight + 2,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              itemCount: 3,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.smd),
              itemBuilder: (context, i) =>
                  const SizedBox(width: 164, child: ProductCardSkeleton()),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
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
  Widget build(BuildContext context) => ListSkeleton(itemCount: itemCount);
}
