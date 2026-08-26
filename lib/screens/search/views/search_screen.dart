import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_kicker.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../route/route_constants.dart';

/// Search screen. Matches the reference theme's `search-screen`: a query
/// field over the catalogue's name/tagline/category text.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search sprinklers, filters, kits…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: () => setState(() {
                _controller.clear();
                _query = '';
              }),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Could not search: $err')),
        data: (data) {
          if (_query.trim().isEmpty) {
            return _RecentAndPopular(products: data.featuredProducts);
          }
          final results = data.search(_query);
          if (results.isEmpty) {
            return Center(
              child: Text(
                'No products found for "$_query"',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.64,
            ),
            itemBuilder: (context, i) => CatalogProductCard(
              product: results[i],
              onTap: () => Navigator.pushNamed(
                context,
                productDetailsScreenRoute,
                arguments: results[i].slug,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentAndPopular extends StatelessWidget {
  const _RecentAndPopular({required this.products});

  final List<CatalogProduct> products;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular searches',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _SuggestionChip('Sprinklers'),
              _SuggestionChip('Drip kit'),
              _SuggestionChip('Filters'),
              _SuggestionChip('Ball valve'),
              _SuggestionChip('Fogger'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppKicker('You might like'),
          Text(
            'Popular right now',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.64,
            ),
            itemBuilder: (context, i) => CatalogProductCard(
              product: products[i],
              onTap: () => Navigator.pushNamed(
                context,
                productDetailsScreenRoute,
                arguments: products[i].slug,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: () {});
  }
}
