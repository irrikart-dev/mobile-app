import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../entry_point_tab.dart';
import '../../../models/catalog_data.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';

/// Wishlist screen, reached from the Account menu or a product's heart
/// icon. Matches the reference theme's `wishlist` route.
class BookmarkScreen extends ConsumerWidget {
  const BookmarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistControllerProvider);
    final catalog = ref.watch(catalogDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: catalog.when(
        loading: () => const CatalogGridSkeleton(),
        error: (err, st) =>
            Center(child: Text('Could not load wishlist: $err')),
        data: (data) {
          final products =
              data.products.where((p) => wishlist.contains(p.slug)).toList();

          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 72,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Your wishlist is empty',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tap the heart on any product to save it here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(entryTabIndexProvider.notifier).state = 0;
                        Navigator.popUntil(
                          context,
                          (route) => route.settings.name == entryPointScreenRoute,
                        );
                      },
                      child: const Text('Browse products'),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.60,
            ),
            itemBuilder: (context, i) => CatalogProductCard(
              product: products[i],
              onTap: () => Navigator.pushNamed(
                context,
                productDetailsScreenRoute,
                arguments: products[i].slug,
              ),
            ),
          );
        },
      ),
    );
  }
}
