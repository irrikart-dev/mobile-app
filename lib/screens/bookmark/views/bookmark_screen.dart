import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../components/ui/ui.dart';
import '../../../entry_point_tab.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';

/// Wishlist, reached from the Account tab or a product's heart icon.
class BookmarkScreen extends ConsumerWidget {
  const BookmarkScreen({super.key});

  void _explore(BuildContext context, WidgetRef ref) {
    ref.read(entryTabIndexProvider.notifier).state = 0;
    var found = false;
    Navigator.popUntil(context, (route) {
      if (route.settings.name == entryPointScreenRoute || route.isFirst) {
        found = true;
      }
      return found;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slugs = ref.watch(wishlistControllerProvider);
    final catalog = ref.watch(catalogDataProvider);

    // Most recently added last in the Set → show newest first.
    final data = catalog.valueOrNull;
    final products = data == null
        ? null
        : slugs.toList().reversed
            .map(data.productBySlug)
            .whereType<CatalogProduct>()
            .toList();

    final count = products?.length ?? slugs.length;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppTopBar(
        title: 'Wishlist',
        subtitle: count == 0
            ? null
            : count == 1
                ? '1 item'
                : '$count items',
      ),
      body: switch (catalog) {
        _ when products != null => products.isEmpty
            ? EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Your wishlist is empty',
                message: 'Tap the heart on any pump, pipe or drip kit to '
                    'save it here for later.',
                actionLabel: 'Explore products',
                onAction: () => _explore(context, ref),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(catalogDataProvider.future),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sm),
                    ),
                    SliverProductGrid(products: products),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: AppSpacing.xl + context.bottomInset,
                      ),
                    ),
                  ],
                ),
              ),
        AsyncValue(:final error?) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(catalogDataProvider),
          ),
        _ => const CatalogGridSkeleton(),
      },
    );
  }
}
