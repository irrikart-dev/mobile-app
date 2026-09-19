import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_kicker.dart';
import '../../../components/product/catalog_grid_skeleton.dart';
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

  void _searchFor(String query) {
    setState(() {
      _controller.text = query;
      _controller.selection = TextSelection.collapsed(offset: query.length);
      _query = query;
    });
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
        loading: () => const CatalogGridSkeleton(),
        error: (err, st) => Center(child: Text('Could not search: $err')),
        data: (data) {
          if (_query.trim().isEmpty) {
            // No `featured` flag any more — highest-rated buyable products
            // stand in for "Popular right now".
            final popular = data.products.where((p) => p.buyable).toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));
            return _RecentAndPopular(
              products: popular.take(8).toList(),
              onSuggestionTap: _searchFor,
            );
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
              childAspectRatio: 0.60,
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
  const _RecentAndPopular({
    required this.products,
    required this.onSuggestionTap,
  });

  final List<CatalogProduct> products;
  final ValueChanged<String> onSuggestionTap;

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
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final label in const [
                'Sprinklers',
                'Drip kit',
                'Filters',
                'Ball valve',
                'Fogger',
              ])
                _SuggestionChip(label, onTap: onSuggestionTap),
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
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label, {required this.onTap});

  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: () => onTap(label));
  }
}
