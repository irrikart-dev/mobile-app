import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_product_card.dart';
import '../../../components/ui/ui.dart';
import '../../../entry_point_tab.dart';
import '../../../models/cart_state.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';
import '../../reviews/view/product_reviews_screen.dart';
import 'components/add_to_cart_bar.dart';
import 'components/bulk_order_card.dart';
import 'components/delivery_info_card.dart';
import 'components/demo_video_card.dart';
import 'components/pdp_reviews_section.dart';
import 'components/pdp_top_bar.dart';
import 'components/product_gallery.dart';
import 'components/product_overview.dart';
import 'components/quick_facts.dart';
import 'components/spec_table.dart';
import 'components/variant_selector.dart';

/// Product detail page: a full-bleed sage gallery under floating round
/// buttons, overlapped by a white rounded sheet (category, name, rating,
/// price + stock, quick facts, options, then un-boxed sections for the
/// description, specs, delivery, reviews, bulk quote and related products),
/// with a sticky quantity + add-to-cart footer.
class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  final _scroll = ScrollController();
  int _qty = 1;
  String? _selectedVariantId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentlyViewedProvider.notifier).record(widget.slug);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _selectVariant(String id) {
    if (id == _selectedVariantId) return;
    setState(() {
      _selectedVariantId = id;
      _qty = 1;
    });
  }

  /// Back to the tab shell's Cart tab if this page sits on top of it;
  /// otherwise (deep link with no shell underneath) push the cart screen.
  void _goToCart() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final tab = ref.read(entryTabIndexProvider.notifier);
    var inShell = false;
    nav.popUntil((route) {
      if (route.settings.name == entryPointScreenRoute) {
        inShell = true;
        return true;
      }
      return route.isFirst;
    });
    if (inShell) {
      tab.state = 2;
    } else {
      nav.pushNamed(cartScreenRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogDataProvider);

    return catalog.when(
      skipLoadingOnRefresh: true,
      loading: () => const _PdpSkeleton(),
      error: (err, _) => Scaffold(
        appBar: const AppTopBar(),
        body: ErrorState(
          error: err,
          onRetry: () => ref.invalidate(catalogDataProvider),
        ),
      ),
      data: (data) {
        final product = data.productBySlug(widget.slug);
        if (product == null) {
          return Scaffold(
            appBar: const AppTopBar(),
            body: EmptyState(
              icon: Icons.inventory_2_rounded,
              title: 'Product not found',
              message: 'It may have been removed or is no longer available.',
              actionLabel: 'Go back',
              onAction: () => Navigator.maybePop(context),
            ),
          );
        }
        final variant = product.variants.firstWhere(
          (v) => v.id == _selectedVariantId,
          orElse: () => product.variants.isNotEmpty
              ? product.variants.first
              : CatalogVariant(
                  id: product.variantId,
                  sku: product.sku,
                  size: null,
                  color: null,
                  unit: product.unit,
                  price: product.price,
                  stockQty: product.stockQty,
                  available: product.stockQty,
                ),
        );
        final related = data
            .productsInCategory(product.category)
            .where((p) => p.slug != product.slug)
            .take(10)
            .toList();

        // Never let the chosen quantity exceed what can actually be bought.
        final maxQty = variant.available < 1 ? 1 : variant.available;
        final qty = _qty.clamp(1, maxQty);

        final categoryLabel = product.categoryName.isNotEmpty
            ? product.categoryName
            : data.categoryById(product.category)?.name ?? '';

        return _ProductDetailsBody(
          scroll: _scroll,
          product: product,
          categoryLabel: categoryLabel,
          variant: variant,
          related: related,
          qty: qty,
          maxQty: maxQty,
          onQtyChanged: (q) => setState(() => _qty = q),
          onVariantChanged: _selectVariant,
          onGoToCart: _goToCart,
        );
      },
    );
  }
}

/// Horizontal padding for everything on the PDP sheet.
const double _pad = AppSpacing.mdPlus;

/// How far the content sheet rides up over the gallery.
const double _overlap = 28;

const BorderRadius _sheetRadius = BorderRadius.vertical(
  top: Radius.circular(32),
);

double _galleryHeight(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  // Square-ish photo stage under the status bar, capped on tablets.
  return MediaQuery.paddingOf(context).top + (width * 1.02).clamp(320.0, 520.0);
}

class _ProductDetailsBody extends ConsumerWidget {
  const _ProductDetailsBody({
    required this.scroll,
    required this.product,
    required this.categoryLabel,
    required this.variant,
    required this.related,
    required this.qty,
    required this.maxQty,
    required this.onQtyChanged,
    required this.onVariantChanged,
    required this.onGoToCart,
  });

  final ScrollController scroll;
  final CatalogProduct product;
  final String categoryLabel;
  final CatalogVariant variant;
  final List<CatalogProduct> related;
  final int qty;
  final int maxQty;
  final ValueChanged<int> onQtyChanged;
  final ValueChanged<String> onVariantChanged;
  final VoidCallback onGoToCart;

  void _openReviews(BuildContext context) => Navigator.pushNamed(
        context,
        productReviewsScreenRoute,
        arguments: ProductReviewsArgs(
          productId: product.id,
          productName: product.name,
        ),
      );

  List<QuickFact> _facts() {
    final available = variant.available;
    return [
      QuickFact(
        icon: Icons.inventory_2_rounded,
        value: !variant.buyable
            ? 'Sold out'
            : available > 99
                ? '99+'
                : '$available',
        label: 'Available',
      ),
      QuickFact(
        icon: Icons.straighten_rounded,
        value: _capitalize(variant.unit),
        label: 'Sold per',
      ),
      if (product.variants.length > 1)
        QuickFact(
          icon: Icons.tune_rounded,
          value: '${product.variants.length}',
          label: 'Options',
        )
      else if (product.reviewCount > 0)
        QuickFact(
          icon: Icons.star_rounded,
          value: product.rating.toStringAsFixed(1),
          label: 'Rating',
        )
      else
        const QuickFact(
          icon: Icons.verified_user_rounded,
          value: 'Prepaid',
          label: 'Secure pay',
        ),
      const QuickFact(
        icon: Icons.local_shipping_rounded,
        value: '24–48h',
        label: 'Dispatch',
      ),
    ];
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isWishlisted = ref.watch(
      wishlistControllerProvider.select((s) => s.contains(product.slug)),
    );
    final cartCount = ref.watch(cartTotalItemsProvider);
    final galleryImages = product.images.isNotEmpty
        ? product.images
        : [if (product.displayImage != null) product.displayImage!];
    final topInset = MediaQuery.paddingOf(context).top;
    final galleryHeight = _galleryHeight(context);

    final sections = <Widget>[
      if (product.features.isNotEmpty || product.description.trim().isNotEmpty)
        _Section(
          title: 'About this product',
          child: ProductOverview(
            features: product.features,
            description: product.description,
          ),
        ),
      if (product.specs.isNotEmpty)
        _Section(
          title: 'Specifications',
          gap: AppSpacing.xs,
          child: SpecTable(specs: product.specs),
        ),
      _Section(
        title: 'Delivery & returns',
        gap: AppSpacing.xs,
        child: DeliveryInfoCard(
          onReturnsTap: () =>
              Navigator.pushNamed(context, productReturnsScreenRoute),
        ),
      ),
      if (product.videoUrl != null && product.videoUrl!.isNotEmpty)
        _Section(
          title: 'See it in action',
          gap: AppSpacing.xs,
          child: DemoVideoCard(url: product.videoUrl!),
        ),
      _Section(
        title: 'Ratings & reviews',
        onSeeAll: () => _openReviews(context),
        child: PdpReviewsSection(
          productId: product.id,
          fallbackRating: product.rating,
          fallbackCount: product.reviewCount,
          onSeeAll: () => _openReviews(context),
        ),
      ),
    ];

    final sheet = DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: _sheetRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _pad,
              AppSpacing.xl - 4,
              _pad,
              AppSpacing.xl - 4,
            ),
            child: _TitleBlock(
              product: product,
              categoryLabel: categoryLabel,
              variant: variant,
              facts: _facts(),
              onRatingTap: () => _openReviews(context),
              onVariantChanged: onVariantChanged,
            ),
          ),
          for (final section in sections) ...[
            const Divider(height: 1, indent: _pad, endIndent: _pad),
            section,
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(_pad, AppSpacing.sm, _pad, 0),
            child: BulkOrderCard(
              productName: product.name,
              sku: variant.sku.isNotEmpty ? variant.sku : product.sku,
            ),
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xlPlus),
            const SectionHeader(
              title: 'You may also like',
              subtitle: 'More from this category',
              padding: EdgeInsets.symmetric(horizontal: _pad),
            ),
            const SizedBox(height: AppSpacing.md),
            _RelatedRail(products: related),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: c.background,
      bottomNavigationBar: AddToCartBar(
        product: product,
        variant: variant,
        qty: qty,
        maxQty: maxQty,
        onQtyChanged: onQtyChanged,
        onGoToCart: onGoToCart,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: galleryHeight,
                      child: ProductGallery(
                        // Re-key per product so the page resets when
                        // navigating between related products.
                        key: ValueKey(product.slug),
                        images: galleryImages,
                        isRemote:
                            product.images.isNotEmpty || product.hasRemoteImage,
                        height: galleryHeight,
                        overlap: _overlap,
                        dimmed: !variant.buyable,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: galleryHeight - _overlap),
                      child: sheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: scroll,
              builder: (context, _) {
                final offset = scroll.hasClients ? scroll.offset : 0.0;
                // Turn solid just as the sheet's edge reaches the bar.
                final start = galleryHeight - _overlap - topInset - 120;
                final progress = (offset - start) / 56;
                return PdpTopBar(
                  progress: progress,
                  title: product.name,
                  onBack: () => Navigator.maybePop(context),
                  wishlisted: isWishlisted,
                  onWishlist: () => ref
                      .read(wishlistControllerProvider.notifier)
                      .toggle(product.slug),
                  cartCount: cartCount,
                  onCart: onGoToCart,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// An un-boxed PDP section: generous vertical rhythm, an h3 title (with an
/// optional "See all"), then the content. The caller separates sections
/// with hairline dividers.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.gap = AppSpacing.md,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;

  /// Space between the title and the content.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _pad,
        AppSpacing.xl - 4,
        _pad,
        AppSpacing.xl - 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            padding: EdgeInsets.zero,
            onAction: onSeeAll,
          ),
          SizedBox(height: gap),
          child,
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.product,
    required this.categoryLabel,
    required this.variant,
    required this.facts,
    required this.onRatingTap,
    required this.onVariantChanged,
  });

  final CatalogProduct product;
  final String categoryLabel;
  final CatalogVariant variant;
  final List<QuickFact> facts;
  final VoidCallback onRatingTap;
  final ValueChanged<String> onVariantChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, tone) = !variant.buyable
        ? ('Out of stock', Tone.error)
        : variant.available <= 5
            ? ('Only ${variant.available} left', Tone.warning)
            : ('In stock', Tone.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categoryLabel.isNotEmpty) ...[
          Text(
            categoryLabel.toUpperCase(),
            style: context.text.overline.copyWith(color: c.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(product.name, style: context.text.h1),
        if (product.tagline.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(product.tagline, style: context.text.bodySecondary),
        ],
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onRatingTap,
          borderRadius: AppRadius.xsAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RatingLabel(
                  rating: product.rating,
                  count: product.reviewCount,
                  compact: false,
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.sm,
                  color: c.textMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: PriceText(variant.price, large: true)),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '/ ${variant.unit}',
                      style: context.text.caption,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: StatusPill(label: label, tone: tone, dot: true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Inclusive of all taxes', style: context.text.captionMuted),
        const SizedBox(height: AppSpacing.lg),
        QuickFactsRow(facts: facts),
        if (product.variants.length > 1) ...[
          const SizedBox(height: AppSpacing.lg + 4),
          VariantSelector(
            variants: product.variants,
            selectedId: variant.id,
            onSelected: onVariantChanged,
          ),
        ],
      ],
    );
  }
}

/// "You may also like" — frameless product cards, aligned to the sheet's
/// padding rather than the app-wide gutter.
class _RelatedRail extends StatelessWidget {
  const _RelatedRail({required this.products});

  final List<CatalogProduct> products;

  static const double _cardWidth = 156;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cardWidth + kProductCardContentHeight + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _pad),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md - 2),
        itemBuilder: (context, i) => SizedBox(
          width: _cardWidth,
          child: CatalogProductCard(product: products[i]),
        ),
      ),
    );
  }
}

class _PdpSkeleton extends StatelessWidget {
  const _PdpSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;
    final galleryHeight = _galleryHeight(context);
    const tile = Expanded(
      child: ShimmerBox(height: 92, borderRadius: AppRadius.lgAll),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: galleryHeight,
            child: ColoredBox(color: c.tint),
          ),
          Padding(
            padding: EdgeInsets.only(top: galleryHeight - _overlap),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: _sheetRadius,
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(_pad, AppSpacing.xl - 4, _pad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 10, width: 90),
                      SizedBox(height: AppSpacing.smd),
                      ShimmerBox(height: 26, width: 240),
                      SizedBox(height: AppSpacing.sm),
                      ShimmerBox(height: 14, width: 200),
                      SizedBox(height: AppSpacing.lg),
                      ShimmerBox(height: 30, width: 140),
                      SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          tile,
                          SizedBox(width: AppSpacing.smd - 2),
                          tile,
                          SizedBox(width: AppSpacing.smd - 2),
                          tile,
                          SizedBox(width: AppSpacing.smd - 2),
                          tile,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + AppSpacing.xs,
            left: AppSpacing.md,
            child: Material(
              color: c.background,
              shape: const CircleBorder(),
              child: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
