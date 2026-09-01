import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_kicker.dart';
import '../../../components/glass/glass_app_bar.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/catalog_data.dart';
import '../../../route/route_constants.dart';
import 'components/category_scroller.dart';
import 'components/home_banner.dart';
import 'components/product_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogDataProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Namaste 🙏',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
            ),
            Text(
              'Grow more with IrriKart',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, searchScreenRoute),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, notificationsScreenRoute),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text('Could not load catalogue: $err')),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(catalogDataProvider),
          child: ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  AppSpacing.md,
              bottom: 120,
            ),
            children: [
              // The catalogue fell back to the bundled fixtures, so anything
              // added in the admin dashboard is missing until a refresh works.
              if (data.isOffline) const _OfflineCatalogueNotice(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: HomeBanner(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppKicker('Browse'),
                    Text(
                      'Shop by category',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CategoryScroller(categories: data.categories),
              const SizedBox(height: AppSpacing.lg),
              ProductSection(
                kicker: 'Handpicked',
                title: 'Featured for you',
                products: data.featuredProducts,
              ),
              const SizedBox(height: AppSpacing.lg),
              ProductSection(
                kicker: 'Just in',
                title: 'New & noteworthy',
                products: data.products.take(8).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _TrustStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const items = [
      (Icons.verified_outlined, 'Genuine parts'),
      (Icons.local_shipping_outlined, 'Pan-India delivery'),
      (Icons.support_agent_outlined, 'Farmer support'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in items)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, color: theme.colorScheme.primary),
                const SizedBox(height: 6),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Shown when the live catalogue could not be reached and the app is rendering
/// its bundled copy. Pull to refresh retries.
class _OfflineCatalogueNotice extends StatelessWidget {
  const _OfflineCatalogueNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Showing the saved catalogue — pull down to refresh once you are '
              'back online.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
