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
import 'components/spec_table.dart';
import 'components/variant_selector.dart';

/// Product detail page: full-bleed gallery under a floating top bar, then a
/// content sheet (title, rating, price, stock, options, quantity, delivery
/// promises, highlights, specs, demo video, reviews, bulk quote, related
/// products) and a sticky add-to-cart footer.
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

        return _ProductDetailsBody(
          scroll: _scroll,
          product: product,
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

class _ProductDetailsBody extends ConsumerWidget {
  const _ProductDetailsBody({
    required this.scroll,
    required this.product,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    const sectionGap = SizedBox(height: AppSpacing.sectionGap);

    final content = <Widget>[
      _TitleBlock(
        product: product,
        variant: variant,
        onRatingTap: () => _openReviews(context),
      ),
      if (product.variants.length > 1) ...[
        const SizedBox(height: AppSpacing.lg),
        VariantSelector(
          variants: product.variants,
          selectedId: variant.id,
          onSelected: onVariantChanged,
        ),
      ],
      if (variant.buyable) ...[
        const SizedBox(height: AppSpacing.lg),
        _QuantityRow(
          qty: qty,
          max: maxQty,
          available: variant.available,
          onChanged: onQtyChanged,
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      DeliveryInfoCard(
        onReturnsTap: () =>
            Navigator.pushNamed(context, productReturnsScreenRoute),
      ),
      if (product.features.isNotEmpty ||
          product.description.trim().isNotEmpty) ...[
        sectionGap,
        ProductOverview(
          features: product.features,
          description: product.description,
        ),
      ],
      if (product.specs.isNotEmpty) ...[
        sectionGap,
        Text('Specifications', style: context.text.h3),
        const SizedBox(height: AppSpacing.smd),
        SpecTable(specs: product.specs),
      ],
      if (product.videoUrl != null && product.videoUrl!.isNotEmpty) ...[
        sectionGap,
        DemoVideoCard(url: product.videoUrl!),
      ],
      sectionGap,
      PdpReviewsSection(
        productId: product.id,
        fallbackRating: product.rating,
        fallbackCount: product.reviewCount,
        onSeeAll: () => _openReviews(context),
      ),
      sectionGap,
      BulkOrderCard(
        productName: product.name,
        sku: variant.sku.isNotEmpty ? variant.sku : product.sku,
      ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      bottomNavigationBar: AddToCartBar(
        product: product,
        variant: variant,
        qty: qty,
        onGoToCart: onGoToCart,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(
                child: ProductGallery(
                  // Re-key per product so the page resets when navigating
                  // between related products.
                  key: ValueKey(product.slug),
                  images: galleryImages,
                  isRemote:
                      product.images.isNotEmpty || product.hasRemoteImage,
                  dimmed: !variant.buyable,
                ),
              ),
              SliverToBoxAdapter(
                child: ColoredBox(
                  color: c.surfaceSunken,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: AppRadius.sheetTop,
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.lg,
                      AppSpacing.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
                  ),
                ),
              ),
              if (related.isNotEmpty) ...[
                const SliverToBoxAdapter(child: sectionGap),
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'You may also like',
                    subtitle: 'More from this category',
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.smd),
                ),
                SliverToBoxAdapter(child: ProductRail(products: related)),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xl),
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
                final start = screenWidth * 0.55;
                final progress = (offset - start) / (screenWidth * 0.3);
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

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.product,
    required this.variant,
    required this.onRatingTap,
  });

  final CatalogProduct product;
  final CatalogVariant variant;
  final VoidCallback onRatingTap;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = !variant.buyable
        ? ('Out of stock', Tone.error)
        : variant.available <= 5
            ? ('Only ${variant.available} left', Tone.warning)
            : ('In stock', Tone.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.categoryName.isNotEmpty) ...[
          Text(
            product.categoryName.toUpperCase(),
            style: context.text.overline.copyWith(
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(product.name, style: context.text.h2),
        if (product.tagline.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(product.tagline, style: context.text.bodySecondary),
        ],
        const SizedBox(height: AppSpacing.smd),
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
                  size: 18,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PriceBlock(
                price: variant.price,
                unit: variant.unit,
                large: true,
                note: 'Inclusive of all taxes',
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: StatusPill(label: label, tone: tone, dot: true),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.qty,
    required this.max,
    required this.available,
    required this.onChanged,
  });

  final int qty;
  final int max;
  final int available;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quantity', style: context.text.title),
              if (qty >= max) ...[
                const SizedBox(height: 2),
                Text(
                  'Max $available available',
                  style: context.text.captionMuted,
                ),
              ],
            ],
          ),
        ),
        QuantityStepper(value: qty, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _PdpSkeleton extends StatelessWidget {
  const _PdpSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          AspectRatio(
            aspectRatio: 1.2,
            child: ShimmerBox(borderRadius: BorderRadius.zero),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 10, width: 90),
                SizedBox(height: AppSpacing.smd),
                ShimmerBox(height: 22, width: 260),
                SizedBox(height: AppSpacing.sm),
                ShimmerBox(height: 22, width: 180),
                SizedBox(height: AppSpacing.md),
                ShimmerBox(height: 14, width: 120),
                SizedBox(height: AppSpacing.lg),
                ShimmerBox(height: 30, width: 140),
                SizedBox(height: AppSpacing.lg),
                ShimmerBox(height: 180, borderRadius: AppRadius.mdAll),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
