import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/glass/glass_sheet.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/theme/tokens/typography_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cart_state.dart';
import '../../../models/catalog_data.dart';
import '../../../models/catalog_product.dart';
import '../../../models/wishlist_state.dart';
import 'components/info_sheet.dart';
import 'components/product_list_tile.dart';
import 'components/shipping_info_sheet.dart';
import 'product_returns_screen.dart';

/// Product detail screen. Matches the reference theme's
/// `product-detail-screen`: image, tagline, price + unit, quantity, add to
/// cart, then details/shipping/returns rows opening as glass sheets.
class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogDataProvider);

    return catalog.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('Could not load product: $err'))),
      data: (data) {
        final product = data.productBySlug(widget.slug);
        if (product == null) {
          return const Scaffold(
            body: Center(child: Text('Product not found')),
          );
        }
        return _ProductDetailsBody(
          product: product,
          qty: _qty,
          onQtyChanged: (q) => setState(() => _qty = q),
        );
      },
    );
  }
}

class _ProductDetailsBody extends ConsumerWidget {
  const _ProductDetailsBody({
    required this.product,
    required this.qty,
    required this.onQtyChanged,
  });

  final CatalogProduct product;
  final int qty;
  final ValueChanged<int> onQtyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;
    final isWishlisted = ref.watch(
      wishlistControllerProvider.select((s) => s.contains(product.slug)),
    );

    return Scaffold(
      bottomNavigationBar: _AddToCartBar(product: product, qty: qty),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              floating: true,
              actions: [
                IconButton(
                  onPressed: () => ref
                      .read(wishlistControllerProvider.notifier)
                      .toggle(product.slug),
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? Colors.redAccent : null,
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.lgAll,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.asset(product.image, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      product.tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ext.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: ext.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${product.rating}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ' (${product.reviewCount} reviews)',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        _StockPill(inStock: product.inStock),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatInr(product.price),
                          style: AppTypography.price(
                            theme.colorScheme.primary,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatUnit(product.unit),
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (product.discountPercent > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatInr(product.mrp),
                            style: AppTypography.strikePrice(
                              ext.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (product.discountPercent > 0)
                      Text(
                        '${product.discountPercent}% off MRP',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ext.discount,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _QuantityStepper(qty: qty, onChanged: onQtyChanged),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      product.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            ProductListTile(
              svgSrc: 'assets/icons/Product.svg',
              title: 'Specifications',
              press: () => showGlassSheet(
                context: context,
                builder: (_) => _SpecsSheet(product: product),
              ),
            ),
            ProductListTile(
              svgSrc: 'assets/icons/Delivery.svg',
              title: 'Shipping information',
              press: () => showGlassSheet(
                context: context,
                builder: (_) => const ShippingInfoSheet(),
              ),
            ),
            ProductListTile(
              svgSrc: 'assets/icons/Return.svg',
              title: 'Returns',
              isShowBottomBorder: true,
              press: () => showGlassSheet(
                context: context,
                builder: (_) => const ProductReturnsScreen(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorsExt>()!;
    final color = inStock ? ext.inStock : ext.outOfStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        inStock ? 'In stock' : 'Out of stock',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Quantity', style: theme.textTheme.titleSmall),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: qty > 1 ? () => onChanged(qty - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: () => onChanged(qty + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddToCartBar extends ConsumerWidget {
  const _AddToCartBar({required this.product, required this.qty});

  final CatalogProduct product;
  final int qty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: ElevatedButton.icon(
          onPressed: product.inStock
              ? () {
                  ref
                      .read(cartControllerProvider.notifier)
                      .add(product, qty: qty);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${product.name} to cart')),
                  );
                }
              : null,
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(
            product.inStock
                ? 'Add to cart · ${formatInr(product.price * qty)}'
                : 'Out of stock',
          ),
        ),
      ),
    );
  }
}

class _SpecsSheet extends StatelessWidget {
  const _SpecsSheet({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoSheet(
      title: 'Specifications',
      children: [
        Text('Key features', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final feature in product.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(feature)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Technical specifications', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final spec in product.specs) SpecRow(spec.label, spec.value),
      ],
    );
  }
}
