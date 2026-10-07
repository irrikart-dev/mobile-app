import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/product/catalog_product_card.dart';
import '../../../components/ui/ui.dart';
import '../../../models/catalog_category.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';

/// Live catalogue search: debounced query over name / tagline / SKU /
/// category, with recent and popular searches while the field is empty.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(AppDurations.searchDebounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    final term = value.trim();
    setState(() => _query = term);
    ref.read(recentSearchesProvider.notifier).record(term);
  }

  /// Fills the field with [term] and searches right away (recent searches).
  void _searchFor(String term) {
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    _onSubmitted(term);
    _focusNode.unfocus();
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _openProduct(CatalogProduct product) {
    ref.read(recentSearchesProvider.notifier).record(_query);
    Navigator.pushNamed(
      context,
      productDetailsScreenRoute,
      arguments: product.slug,
    );
  }

  void _openCategory(CatalogCategory category) {
    Navigator.pushNamed(
      context,
      productListScreenRoute,
      arguments: category.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final catalog = ref.watch(catalogDataProvider);

    final List<Widget> slivers = catalog.when(
      loading: () => const [
        SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverProductGridSkeleton(),
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
      data: (data) =>
          _query.isEmpty ? _idle(data) : _results(data, data.search(_query)),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AppSearchField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      onChanged: _onChanged,
                      onSubmitted: _onSubmitted,
                      onClear: _clear,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  ...slivers,
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: AppSpacing.xl + context.bottomInset,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty query: recent searches, popular categories, top-rated products.
  List<Widget> _idle(CatalogData data) {
    final c = context.colors;
    final recents = ref.watch(recentSearchesProvider);
    final trending = data.products.where((p) => p.buyable).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return [
      if (recents.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Recent searches', style: context.text.h3),
                ),
                AppButton.ghost(
                  label: 'Clear all',
                  size: AppButtonSize.sm,
                  onPressed: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: recents.length,
          itemBuilder: (context, i) {
            final term = recents[i];
            return InkWell(
              onTap: () => _searchFor(term),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.gutter,
                  right: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: AppIconSize.sm,
                      color: c.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.body,
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.close_rounded,
                      iconSize: AppIconSize.sm,
                      color: c.textMuted,
                      tooltip: 'Remove',
                      onPressed: () => ref
                          .read(recentSearchesProvider.notifier)
                          .remove(term),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
      if (data.categories.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.mdPlus)),
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Popular categories'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smd)),
        SliverToBoxAdapter(child: _CategoryChips(data.categories, _openCategory)),
      ],
      if (trending.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sectionGap)),
        const SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Trending products',
            subtitle: 'Top rated by farmers',
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smd)),
        SliverProductGrid(
          products: trending.take(6).toList(),
          onProductTap: _openProduct,
        ),
      ],
    ];
  }

  List<Widget> _results(CatalogData data, List<CatalogProduct> results) {
    final c = context.colors;
    if (results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results for “$_query”',
                message: 'Check the spelling, try a shorter word, or browse '
                    'one of these categories.',
                compact: true,
              ),
              if (data.categories.isNotEmpty)
                _CategoryChips(data.categories.take(6).toList(), _openCategory),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.smd,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${results.length} ',
                  style: context.text.label.copyWith(color: c.textPrimary),
                ),
                TextSpan(
                  text: results.length == 1 ? 'result for ' : 'results for ',
                ),
                TextSpan(
                  text: '“$_query”',
                  style: context.text.label.copyWith(color: c.textPrimary),
                ),
              ],
            ),
            style: context.text.caption,
          ),
        ),
      ),
      SliverProductGrid(products: results, onProductTap: _openProduct),
    ];
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips(this.categories, this.onTap);

  final List<CatalogCategory> categories;
  final ValueChanged<CatalogCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.center,
        children: [
          for (final category in categories)
            AppChip(
              label: category.name,
              icon: Icons.trending_up_rounded,
              onTap: () => onTap(category),
            ),
        ],
      ),
    );
  }
}
