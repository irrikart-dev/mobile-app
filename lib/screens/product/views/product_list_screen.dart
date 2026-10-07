import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../components/ui/ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../route/route_constants.dart';

// The catalogue is server-sorted by `updatedAt` descending, so "Relevance"
// just leaves the list in whatever order the API returned.
enum _SortOption { relevance, priceAsc, priceDesc, rating, name }

extension on _SortOption {
  String get label => switch (this) {
        _SortOption.relevance => 'Relevance',
        _SortOption.priceAsc => 'Price: low to high',
        _SortOption.priceDesc => 'Price: high to low',
        _SortOption.rating => 'Top rated',
        _SortOption.name => 'Name: A–Z',
      };

  String get chipLabel => switch (this) {
        _SortOption.relevance => 'Sort',
        _SortOption.priceAsc => 'Price ↑',
        _SortOption.priceDesc => 'Price ↓',
        _SortOption.rating => 'Top rated',
        _SortOption.name => 'A–Z',
      };

  IconData get icon => switch (this) {
        _SortOption.relevance => Icons.auto_awesome_rounded,
        _SortOption.priceAsc => Icons.trending_up_rounded,
        _SortOption.priceDesc => Icons.trending_down_rounded,
        _SortOption.rating => Icons.star_rounded,
        _SortOption.name => Icons.sort_by_alpha_rounded,
      };
}

/// Product listing for one category: in-stock / sort / price filters over a
/// product grid.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  _SortOption _sort = _SortOption.relevance;
  bool _inStockOnly = false;

  /// Null means "any price".
  RangeValues? _price;

  bool get _hasFilters =>
      _inStockOnly || _price != null || _sort != _SortOption.relevance;

  void _clearFilters() => setState(() {
        _inStockOnly = false;
        _price = null;
        _sort = _SortOption.relevance;
      });

  List<CatalogProduct> _apply(List<CatalogProduct> products) {
    var list = [...products];
    if (_inStockOnly) list = list.where((p) => p.buyable).toList();
    final price = _price;
    if (price != null) {
      list = list
          .where((p) => p.price >= price.start && p.price <= price.end)
          .toList();
    }
    switch (_sort) {
      case _SortOption.relevance:
        break; // already server-sorted
      case _SortOption.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _SortOption.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _SortOption.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _SortOption.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return list;
  }

  Future<void> _pickSort() async {
    final picked = await showAppSheet<_SortOption>(
      context,
      title: 'Sort by',
      builder: (sheetContext) => _SortSheet(current: _sort),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Future<void> _pickPrice(double min, double max) async {
    final picked = await showAppSheet<RangeValues>(
      context,
      title: 'Price range',
      builder: (sheetContext) => _PriceSheet(
        min: min,
        max: max,
        initial: _price ?? RangeValues(min, max),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      // A full-width range is the same as no filter.
      _price = (picked.start <= min && picked.end >= max) ? null : picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final catalog = ref.watch(catalogDataProvider);
    final data = catalog.valueOrNull;
    final category = data?.categoryById(widget.categoryId);
    final all = data?.productsInCategory(widget.categoryId) ?? const [];
    final products = _apply(all);

    final prices = all.map((p) => p.price.toDouble()).toList();
    final minPrice =
        prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxPrice =
        prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);
    final canFilterPrice = maxPrice > minPrice;

    final List<Widget> body = catalog.when(
      loading: () => const [SliverProductGridSkeleton()],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            error: error,
            onRetry: () => ref.invalidate(catalogDataProvider),
          ),
        ),
      ],
      data: (_) {
        if (products.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _hasFilters && all.isNotEmpty
                  ? EmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Nothing matches these filters',
                      message: 'Try a wider price range or include '
                          'out-of-stock items.',
                      actionLabel: 'Clear filters',
                      onAction: _clearFilters,
                    )
                  : EmptyState(
                      icon: Icons.inventory_2_rounded,
                      title: 'No products here yet',
                      message: 'We’re adding stock to this category. '
                          'Search the whole store meanwhile.',
                      actionLabel: 'Search products',
                      onAction: () =>
                          Navigator.pushNamed(context, searchScreenRoute),
                    ),
            ),
          ];
        }
        return [SliverProductGrid(products: products)];
      },
    );

    final priceLabel = _price == null
        ? 'Price'
        : '${formatInr(_price!.start)} – ${formatInr(_price!.end)}';

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(
        title: category?.name ?? 'Products',
        subtitle: data == null
            ? null
            : products.length == 1
                ? '1 product'
                : '${products.length} products',
        actions: [
          AppIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () => Navigator.pushNamed(context, searchScreenRoute),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              background: c.background,
              divider: c.divider,
              child: ChipRow(
                children: [
                  AppChip(
                    label: 'In stock',
                    icon: _inStockOnly
                        ? Icons.check_rounded
                        : Icons.inventory_rounded,
                    selected: _inStockOnly,
                    onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                  ),
                  AppChip(
                    label: _sort.chipLabel,
                    icon: Icons.swap_vert_rounded,
                    dropdown: true,
                    selected: _sort != _SortOption.relevance,
                    onTap: _pickSort,
                  ),
                  AppChip(
                    label: priceLabel,
                    icon: Icons.currency_rupee_rounded,
                    dropdown: true,
                    selected: _price != null,
                    enabled: canFilterPrice,
                    onTap: () => _pickPrice(minPrice, maxPrice),
                  ),
                  if (_hasFilters)
                    AppChip(
                      label: 'Clear',
                      icon: Icons.close_rounded,
                      onTap: _clearFilters,
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
          ...body,
          SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xl + context.bottomInset),
          ),
        ],
      ),
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  const _FilterBarDelegate({
    required this.child,
    required this.background,
    required this.divider,
  });

  final Widget child;
  final Color background;
  final Color divider;

  static const double _extent = 36 + AppSpacing.smd * 2;

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
          bottom: BorderSide(color: overlaps ? divider : background),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) => true;
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final _SortOption current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in _SortOption.values)
          InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => Navigator.of(context).pop(option),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.smd,
              ),
              child: Row(
                children: [
                  Icon(
                    option.icon,
                    size: AppIconSize.sm,
                    color: option == current ? c.primary : c.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Text(
                      option.label,
                      style: option == current
                          ? context.text.bodyStrong
                          : context.text.body,
                    ),
                  ),
                  Icon(
                    option == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: AppIconSize.md,
                    color: option == current ? c.primary : c.borderStrong,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({
    required this.min,
    required this.max,
    required this.initial,
  });

  final double min;
  final double max;
  final RangeValues initial;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late RangeValues _values = RangeValues(
    widget.initial.start.clamp(widget.min, widget.max),
    widget.initial.end.clamp(widget.min, widget.max),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _PriceBox(label: 'Min', value: _values.start)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('–', style: context.text.bodySecondary),
            ),
            Expanded(child: _PriceBox(label: 'Max', value: _values.end)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        RangeSlider(
          values: _values,
          min: widget.min,
          max: widget.max,
          activeColor: c.primary,
          inactiveColor: c.border,
          labels: RangeLabels(
            formatInr(_values.start.round()),
            formatInr(_values.end.round()),
          ),
          onChanged: (v) => setState(() => _values = v),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton.outline(
                label: 'Reset',
                onPressed: () => Navigator.of(context).pop(
                  RangeValues(widget.min, widget.max),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: AppButton(
                label: 'Apply',
                onPressed: () => Navigator.of(context).pop(
                  RangeValues(
                    _values.start.floorToDouble(),
                    _values.end.ceilToDouble(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.captionMuted),
          const SizedBox(height: AppSpacing.xxs),
          Text(formatInr(value.round()), style: context.text.price),
        ],
      ),
    );
  }
}
