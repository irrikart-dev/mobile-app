import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_product_card.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../route/route_constants.dart';

enum _SortOption { featured, priceAsc, priceDesc, rating }

extension on _SortOption {
  String get label => switch (this) {
        _SortOption.featured => 'Featured',
        _SortOption.priceAsc => 'Price: Low to High',
        _SortOption.priceDesc => 'Price: High to Low',
        _SortOption.rating => 'Top Rated',
      };
}

/// Product listing for one category. Matches the reference theme's
/// `product-list-screen` (sort dropdown + grid).
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  _SortOption _sort = _SortOption.featured;
  bool _inStockOnly = false;

  List<CatalogProduct> _apply(List<CatalogProduct> products) {
    var list = [...products];
    if (_inStockOnly) list = list.where((p) => p.inStock).toList();
    switch (_sort) {
      case _SortOption.featured:
        list.sort((a, b) => (b.featured ? 1 : 0) - (a.featured ? 1 : 0));
      case _SortOption.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _SortOption.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _SortOption.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogDataProvider);

    return catalog.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('Could not load products: $err'))),
      data: (data) {
        final category = data.categoryById(widget.categoryId);
        final products = _apply(data.productsInCategory(widget.categoryId));

        return Scaffold(
          appBar: AppBar(title: Text(category?.name ?? 'Products')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${products.length} products',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    FilterChip(
                      label: const Text('In stock'),
                      selected: _inStockOnly,
                      onSelected: (v) => setState(() => _inStockOnly = v),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _SortButton(
                      current: _sort,
                      onChanged: (s) => setState(() => _sort = s),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const Center(
                        child: Text('No products match these filters.'),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onChanged});

  final _SortOption current;
  final ValueChanged<_SortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortOption>(
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in _SortOption.values)
          PopupMenuItem(value: option, child: Text(option.label)),
      ],
      child: Chip(
        label: Text(current.label),
        avatar: const Icon(Icons.swap_vert, size: 16),
      ),
    );
  }
}
