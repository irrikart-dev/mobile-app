import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../models/catalog_category.dart';
import '../../../models/catalog_data.dart';
import '../../../route/route_constants.dart';
import '../../home/views/components/category_art.dart';

/// Height of the text under a category tile: name (one line) + count. Text
/// scaling is clamped inside the tile so this always fits.
const double _labelHeight = 52;
const double _gridGap = AppSpacing.md;

/// 2-column grid geometry: square sage tile + fixed label block.
SliverGridDelegate _gridDelegate(double width) {
  final tile = (width - _gridGap) / 2;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: AppSpacing.mdPlus,
    crossAxisSpacing: _gridGap,
    mainAxisExtent: tile + _labelHeight,
  );
}

/// Categories tab — every catalogue category as a frameless 2-column grid
/// of sage tiles, name and product count set on the canvas.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(catalogDataProvider);
    try {
      await ref.read(catalogDataProvider.future);
    } catch (_) {
      // Error state renders itself.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final catalog = ref.watch(catalogDataProvider);
    final count = catalog.valueOrNull?.categories.length;

    final List<Widget> body = catalog.when(
      loading: () => const [_CategoryGridSkeleton()],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            error: error,
            onRetry: () => ref.invalidate(catalogDataProvider),
          ),
        ),
      ],
      data: (data) {
        if (data.categories.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.category_rounded,
                title: 'No categories yet',
                message: 'We’re setting up the store. Check back soon.',
                actionLabel: 'Refresh',
                onAction: () => ref.invalidate(catalogDataProvider),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid.builder(
                gridDelegate: _gridDelegate(constraints.crossAxisExtent),
                itemCount: data.categories.length,
                itemBuilder: (context, i) {
                  final category = data.categories[i];
                  return _CategoryTile(
                    category: category,
                    productCount: data.productsInCategory(category.id).length,
                  );
                },
              ),
            ),
          ),
        ];
      },
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(
        large: true,
        title: 'Categories',
        subtitle: count == null
            ? 'Browse the full range'
            : '$count ${count == 1 ? 'category' : 'categories'}',
      ),
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: AppSearchField(
                  readOnly: true,
                  onTap: () => Navigator.pushNamed(context, searchScreenRoute),
                ),
              ),
            ),
            ...body,
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppSpacing.fabClearance +
                    MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.productCount});

  final CatalogCategory category;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: PressableScale(
        onTap: () => Navigator.pushNamed(
          context,
          productListScreenRoute,
          arguments: category.id,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CategoryArt(
                category: category,
                radius: AppRadius.xlAll,
                imagePadding: const EdgeInsets.all(AppSpacing.lg),
              ),
            ),
            SizedBox(
              height: _labelHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.title,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      productCount == 1 ? '1 product' : '$productCount products',
                      maxLines: 1,
                      style: context.text.captionMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid.builder(
          gridDelegate: _gridDelegate(constraints.crossAxisExtent),
          itemCount: 6,
          itemBuilder: (context, _) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ShimmerBox(borderRadius: AppRadius.xlAll),
              ),
              SizedBox(height: 12),
              ShimmerBox(height: 14, width: 96),
              SizedBox(height: AppSpacing.sm),
              ShimmerBox(height: 10, width: 64),
            ],
          ),
        ),
      ),
    );
  }
}
