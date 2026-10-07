import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../components/ui/ui.dart';
import '../../../entry_point_tab.dart';
import '../../../models/catalog_category.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';
import 'components/home_banner.dart';
import 'components/home_category_grid.dart';
import 'components/home_header.dart';
import 'components/home_promos.dart';

typedef _Rail = ({CatalogCategory category, List<CatalogProduct> products});

/// There is no `featured` flag in the catalogue contract — "a category rail
/// instead" is the contract's own suggestion — so Home shows the categories
/// with the most buyable products, best first.
List<_Rail> _topCategoryRails(CatalogData data, {int count = 2}) {
  final rails = <_Rail>[];
  for (final category in data.categories) {
    final products =
        data.productsInCategory(category.id).where((p) => p.buyable).toList();
    if (products.length >= 2) {
      rails.add((category: category, products: products.take(10).toList()));
    }
  }
  // Biggest first, but a catch-all ("Other products") makes a weak headline
  // rail, so it only shows when nothing more specific is available.
  bool catchAll(_Rail r) => r.category.name.toLowerCase().startsWith('other');
  rails.sort((a, b) {
    final byKind = (catchAll(a) ? 1 : 0).compareTo(catchAll(b) ? 1 : 0);
    return byKind != 0 ? byKind : b.products.length.compareTo(a.products.length);
  });
  return rails.take(count).toList();
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(catalogDataProvider);
    try {
      await ref.read(catalogDataProvider.future);
    } catch (_) {
      // The error state renders itself; the spinner just needs to stop.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final catalog = ref.watch(catalogDataProvider);

    final List<Widget> body = catalog.when(
      loading: () => const [
        SliverFillRemaining(hasScrollBody: true, child: HomeSkeleton()),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            error: error,
            onRetry: () => ref.invalidate(catalogDataProvider),
          ),
        ),
      ],
      data: (data) => _content(context, ref, data),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: HomeHeader()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchHeaderDelegate(
                  background: c.background,
                  divider: c.divider,
                ),
              ),
              ...body,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, CatalogData data) {
    const gap = SliverToBoxAdapter(
      child: SizedBox(height: AppSpacing.xl),
    );
    const headerGap = SliverToBoxAdapter(
      child: SizedBox(height: AppSpacing.md),
    );

    if (data.categories.isEmpty && data.products.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.storefront_rounded,
            title: 'The shelves are empty',
            message: 'We’re restocking the catalogue. Pull down to refresh.',
          ),
        ),
      ];
    }

    void openCategoriesTab() =>
        ref.read(entryTabIndexProvider.notifier).state = 1;

    final rails = _topCategoryRails(data);
    final recent = [
      for (final slug in ref.watch(recentlyViewedProvider))
        if (data.productBySlug(slug) case final p?) p,
    ];

    Widget railSection(_Rail rail) => SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Popular in ${rail.category.name}',
                onAction: () => Navigator.pushNamed(
                  context,
                  productListScreenRoute,
                  arguments: rail.category.id,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ProductRail(products: rail.products),
            ],
          ),
        );

    return [
      if (data.isOffline) ...[
        const SliverToBoxAdapter(child: HomeOfflineNotice()),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      ] else
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
      SliverToBoxAdapter(child: HomeBanner(data: data)),
      if (data.categories.isNotEmpty) ...[
        gap,
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Shop by category',
            onAction: openCategoriesTab,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverToBoxAdapter(
          child: HomeCategoryGrid(
            categories: data.categories,
            onViewAll: openCategoriesTab,
          ),
        ),
      ],
      if (rails.isNotEmpty) ...[gap, railSection(rails.first)],
      gap,
      const SliverToBoxAdapter(child: HomeBulkOrderCard()),
      if (recent.isNotEmpty) ...[
        gap,
        const SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Recently viewed',
            subtitle: 'Pick up where you left off',
          ),
        ),
        headerGap,
        SliverToBoxAdapter(child: ProductRail(products: recent)),
      ],
      for (final rail in rails.skip(1)) ...[gap, railSection(rail)],
      gap,
      const SliverToBoxAdapter(child: HomeTrustStrip()),
      SliverToBoxAdapter(
        child: SizedBox(
          height: AppSpacing.fabClearance + MediaQuery.paddingOf(context).bottom,
        ),
      ),
    ];
  }
}

/// Keeps the search entry pinned under the status bar while the greeting
/// scrolls away; a hairline appears once content slides beneath it.
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SearchHeaderDelegate({
    required this.background,
    required this.divider,
  });

  final Color background;
  final Color divider;

  static const double _extent = 48 + AppSpacing.smd * 2;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: overlaps ? divider : background,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.smd,
        ),
        child: AppSearchField(
          readOnly: true,
          onTap: () => Navigator.pushNamed(context, searchScreenRoute),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchHeaderDelegate old) =>
      old.background != background || old.divider != divider;
}
