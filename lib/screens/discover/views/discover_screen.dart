import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../components/ui/ui.dart';
import '../../../models/catalog_category.dart';
import '../../../models/catalog_data.dart';
import '../../../route/route_constants.dart';

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: AppSpacing.smd,
  crossAxisSpacing: AppSpacing.smd,
  childAspectRatio: 0.82,
);

/// Categories tab — every catalogue category as a 2-column card grid.
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
            sliver: SliverGrid.builder(
              gridDelegate: _gridDelegate,
              itemCount: data.categories.length,
              itemBuilder: (context, i) {
                final category = data.categories[i];
                return _CategoryCard(
                  category: category,
                  productCount: data.productsInCategory(category.id).length,
                );
              },
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
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: AppSearchField(
                  readOnly: true,
                  onTap: () => Navigator.pushNamed(context, searchScreenRoute),
                ),
              ),
            ),
            ...body,
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.fabClearance),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.productCount});

  final CatalogCategory category;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: () => Navigator.pushNamed(
        context,
        productListScreenRoute,
        arguments: category.id,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: c.border),
          boxShadow: c.shadowCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.smd),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: AppRadius.mdAll,
                ),
                child: CatalogImage(
                  source: category.displayImage,
                  isRemote: category.hasRemoteImage,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.smd,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.smd,
              ),
              child: Row(
                children: [
                  Expanded(
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
                          productCount == 1
                              ? '1 product'
                              : '$productCount products',
                          style: context.text.captionMuted,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: AppIconSize.xs + 2,
                      color: c.textSecondary,
                    ),
                  ),
                ],
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
    final c = context.colors;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverGrid.builder(
        gridDelegate: _gridDelegate,
        itemCount: 6,
        itemBuilder: (context, _) => Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: c.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              SizedBox(height: AppSpacing.smd),
              ShimmerBox(height: 14, width: 96),
              SizedBox(height: AppSpacing.sm - 2),
              ShimmerBox(height: 10, width: 64),
              SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
