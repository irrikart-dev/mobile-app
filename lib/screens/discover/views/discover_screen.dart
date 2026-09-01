import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_kicker.dart';
import '../../../components/catalog_image.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/shadow_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/catalog_category.dart';
import '../../../models/catalog_data.dart';
import '../../../route/route_constants.dart';

/// Categories tab — a grid of the catalogue's 11 categories, matching the
/// reference theme's `categories-screen`.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        automaticallyImplyLeading: false,
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text('Could not load categories: $err')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const AppKicker('Everything you need'),
            Text(
              'Shop by category',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, i) =>
                  _CategoryCard(category: data.categories[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final CatalogCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        productListScreenRoute,
        arguments: category.id,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          boxShadow: AppShadows.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: CatalogImage(
                    source: category.displayImage,
                    isRemote: category.hasRemoteImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    category.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
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
