import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../components/ui/ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../route/route_constants.dart';

extension on CatalogSort {
  String get label => switch (this) {
        CatalogSort.newest => 'Newest',
        CatalogSort.priceAsc => 'Price: low to high',
        CatalogSort.priceDesc => 'Price: high to low',
        CatalogSort.popular => 'Popular',
        CatalogSort.rating => 'Top rated',
      };

  String get chipLabel => switch (this) {
        CatalogSort.newest => 'Sort',
        CatalogSort.priceAsc => 'Price ↑',
        CatalogSort.priceDesc => 'Price ↓',
        CatalogSort.popular => 'Popular',
        CatalogSort.rating => 'Top rated',
      };

  IconData get icon => switch (this) {
        CatalogSort.newest => Icons.schedule_rounded,
        CatalogSort.priceAsc => Icons.trending_up_rounded,
        CatalogSort.priceDesc => Icons.trending_down_rounded,
        CatalogSort.popular => Icons.local_fire_department_rounded,
        CatalogSort.rating => Icons.star_rounded,
      };
}

/// Minimum-rating presets offered by the rating filter.
const _ratingOptions = <double>[4, 3];

String _ratingLabel(double r) => '${r.toStringAsFixed(0)}★ & up';

/// A brand that has products in the category on screen.
typedef _BrandOption = ({String id, String name, int count});

/// Brands present in [products], named from `GET /catalog/brands` where
/// possible (falling back to the product's own denormalised name).
List<_BrandOption> _brandsIn(
  List<CatalogProduct> products,
  List<CatalogBrand> brands,
) {
  final names = {for (final b in brands) b.id: b.name};
  final counts = <String, int>{};
  final fallback = <String, String>{};
  for (final p in products) {
    final id = p.brandId;
    if (id == null || id.isEmpty) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    fallback[id] ??= p.brandName ?? 'Other';
  }
  return [
    for (final e in counts.entries)
      (id: e.key, name: names[e.key] ?? fallback[e.key]!, count: e.value),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Product listing for one category: sort plus brand / rating / in-stock /
/// price filters over a product grid. Filtering happens on the in-memory
/// catalogue (see [CatalogFilter]), so it works the same offline.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  CatalogFilter _filter = const CatalogFilter();

  void _clearFilters() => setState(() => _filter = const CatalogFilter());

  Future<void> _pickSort() async {
    final picked = await showAppSheet<CatalogSort>(
      context,
      title: 'Sort by',
      builder: (sheetContext) => _SortSheet(current: _filter.sort),
    );
    if (picked != null && mounted) {
      setState(() => _filter = _filter.copyWith(sort: picked));
    }
  }

  Future<void> _pickBrands(List<_BrandOption> options) async {
    final picked = await showAppSheet<Set<String>>(
      context,
      title: 'Brand',
      builder: (sheetContext) =>
          _BrandSheet(options: options, initial: _filter.brandIds),
    );
    if (picked != null && mounted) {
      setState(() => _filter = _filter.copyWith(brandIds: picked));
    }
  }

  Future<void> _pickRating() async {
    final picked = await showAppSheet<({double? value})>(
      context,
      title: 'Customer rating',
      builder: (sheetContext) => _RatingSheet(current: _filter.minRating),
    );
    if (picked != null && mounted) {
      setState(
        () => _filter = _filter.copyWith(minRating: () => picked.value),
      );
    }
  }

  Future<void> _pickPrice(double min, double max) async {
    final picked = await showAppSheet<RangeValues>(
      context,
      title: 'Price range',
      builder: (sheetContext) => _PriceSheet(
        min: min,
        max: max,
        initial: RangeValues(
          _filter.minPrice?.toDouble() ?? min,
          _filter.maxPrice?.toDouble() ?? max,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      // A full-width range is the same as no filter.
      final full = picked.start <= min && picked.end >= max;
      _filter = _filter.copyWith(
        price: full
            ? (min: null, max: null)
            : (min: picked.start, max: picked.end),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final catalog = ref.watch(catalogDataProvider);
    final data = catalog.valueOrNull;
    final category = data?.categoryById(widget.categoryId);
    final all = data?.productsInCategory(widget.categoryId) ?? const [];
    final products = _filter.apply(all);

    final prices = [
      for (final p in all) ...CatalogFilter.prices(p).map((v) => v.toDouble()),
    ];
    final minPrice =
        prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxPrice =
        prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);
    final canFilterPrice = maxPrice > minPrice;

    final brandOptions = _brandsIn(
      all,
      ref.watch(brandsProvider).valueOrNull ?? const [],
    );

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
              child: _filter.isActive && all.isNotEmpty
                  ? EmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Nothing matches these filters',
                      message: 'Try another brand, a wider price range or '
                          'include out-of-stock items.',
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

    final priceLabel = !_filter.hasPrice
        ? 'Price'
        : '${formatInr(_filter.minPrice ?? minPrice)} – '
            '${formatInr(_filter.maxPrice ?? maxPrice)}';

    final selectedBrands = _filter.brandIds;
    final brandLabel = switch (selectedBrands.length) {
      0 => 'Brand',
      1 => brandOptions
              .where((b) => b.id == selectedBrands.first)
              .firstOrNull
              ?.name ??
          'Brand',
      final n => '$n brands',
    };

    final rating = _filter.minRating;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(
        large: true,
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
                    label: _filter.sort.chipLabel,
                    icon: Icons.swap_vert_rounded,
                    dropdown: true,
                    selected: _filter.sort != CatalogSort.newest,
                    onTap: _pickSort,
                  ),
                  AppChip(
                    label: 'In stock',
                    icon: _filter.inStockOnly
                        ? Icons.check_rounded
                        : Icons.inventory_rounded,
                    selected: _filter.inStockOnly,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        inStockOnly: !_filter.inStockOnly,
                      ),
                    ),
                  ),
                  // Hidden when nothing in the category carries a brand —
                  // e.g. the offline fixtures, which predate brands.
                  if (brandOptions.isNotEmpty || selectedBrands.isNotEmpty)
                    AppChip(
                      label: brandLabel,
                      icon: Icons.sell_rounded,
                      dropdown: true,
                      selected: selectedBrands.isNotEmpty,
                      onTap: () => _pickBrands(brandOptions),
                    ),
                  AppChip(
                    label: rating == null ? 'Rating' : _ratingLabel(rating),
                    icon: Icons.star_rounded,
                    dropdown: true,
                    selected: rating != null,
                    onTap: _pickRating,
                  ),
                  AppChip(
                    label: priceLabel,
                    icon: Icons.currency_rupee_rounded,
                    dropdown: true,
                    selected: _filter.hasPrice,
                    enabled: canFilterPrice,
                    onTap: () => _pickPrice(minPrice, maxPrice),
                  ),
                  if (_filter.isActive)
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

/// One tappable option row in a filter sheet: leading visual, label, and a
/// trailing radio / checkbox mark.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.selected,
    required this.onTap,
    required this.label,
    this.leading,
    this.trailingNote,
    this.multi = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Widget? leading;
  final String? trailingNote;

  /// Checkbox instead of radio.
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final IconData mark = multi
        ? (selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded)
        : (selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded);
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.smd),
            ],
            Expanded(
              child: Text(
                label,
                style: selected ? context.text.bodyStrong : context.text.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingNote != null) ...[
              Text(trailingNote!, style: context.text.captionMuted),
              const SizedBox(width: AppSpacing.smd),
            ],
            Icon(
              mark,
              size: AppIconSize.md,
              color: selected ? c.primary : c.borderStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final CatalogSort current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in CatalogSort.values)
          _OptionRow(
            selected: option == current,
            label: option.label,
            leading: Icon(
              option.icon,
              size: AppIconSize.sm,
              color: option == current ? c.primary : c.textMuted,
            ),
            onTap: () => Navigator.of(context).pop(option),
          ),
      ],
    );
  }
}

/// Multi-select of the brands present in the category. Pops the chosen
/// set (empty = any brand) on Apply / Reset; null when dismissed.
class _BrandSheet extends StatefulWidget {
  const _BrandSheet({required this.options, required this.initial});

  final List<_BrandOption> options;
  final Set<String> initial;

  @override
  State<_BrandSheet> createState() => _BrandSheetState();
}

class _BrandSheetState extends State<_BrandSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in widget.options)
          _OptionRow(
            multi: true,
            selected: _selected.contains(b.id),
            label: b.name,
            trailingNote: '${b.count}',
            onTap: () => setState(() {
              if (!_selected.remove(b.id)) _selected.add(b.id);
            }),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton.outline(
                label: 'Reset',
                onPressed: () => Navigator.of(context).pop(<String>{}),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: AppButton(
                label: 'Apply',
                onPressed: () => Navigator.of(context).pop({..._selected}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Minimum-rating picker. Pops `(value: null)` for "Any rating".
class _RatingSheet extends StatelessWidget {
  const _RatingSheet({required this.current});

  final double? current;

  /// Fixed leading slot so every label lines up, stars or not.
  static const double _starsWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionRow(
          selected: current == null,
          label: 'Any rating',
          leading: const SizedBox(width: _starsWidth),
          onTap: () => Navigator.of(context).pop((value: null)),
        ),
        for (final r in _ratingOptions)
          _OptionRow(
            selected: current == r,
            label: '${r.toStringAsFixed(0)} stars & up',
            leading: SizedBox(
              width: _starsWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: RatingStars(rating: r, size: 18),
              ),
            ),
            onTap: () => Navigator.of(context).pop((value: r)),
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
        color: c.tint,
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
