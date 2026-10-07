import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import '../../models/cart_state.dart';
import '../../models/catalog_product.dart';
import '../../models/wishlist_state.dart';
import '../../route/route_constants.dart';
import '../catalog_image.dart';
import '../ui/badges.dart';
import '../ui/dialogs.dart';
import '../ui/pressable.dart';
import '../ui/price.dart';
import '../ui/quantity_stepper.dart';
import '../ui/rating.dart';

/// Height of everything below the square image tile. Fixed — every line has
/// a fixed height and text scaling is clamped inside the card — so grids can
/// use an exact `mainAxisExtent` and never overflow.
const double kProductCardContentHeight = 96;

/// Frameless product card for grids and rails: a rounded sage image tile
/// (wishlist heart, stock badge, and a round "+" that becomes a quantity
/// stepper once the item is in the cart), then name, price and rating set
/// directly on the canvas — no card border.
class CatalogProductCard extends ConsumerWidget {
  const CatalogProductCard({super.key, required this.product, this.onTap});

  final CatalogProduct product;

  /// Defaults to opening the product page.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isWishlisted = ref.watch(
      wishlistControllerProvider.select((s) => s.contains(product.slug)),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: PressableScale(
        onTap: onTap ??
            () => Navigator.pushNamed(
                  context,
                  productDetailsScreenRoute,
                  arguments: product.slug,
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: AppRadius.lgAll,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: c.tint,
                      child: Opacity(
                        opacity: product.buyable ? 1 : 0.5,
                        child: CatalogImage(
                          source: product.displayImage,
                          isRemote: product.hasRemoteImage,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: WishlistHeart(
                        active: isWishlisted,
                        onTap: () => ref
                            .read(wishlistControllerProvider.notifier)
                            .toggle(product.slug),
                      ),
                    ),
                    if (!product.buyable)
                      const Positioned(
                        left: 10,
                        top: 10,
                        child: AppBadge(label: 'SOLD OUT'),
                      ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      left: 10,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _CartAction(product: product),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: kProductCardContentHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 36,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSm.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 22,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: PriceText(product.price)),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '/ ${product.unit}',
                              style: context.text.captionMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      child: RatingLabel(
                        rating: product.rating,
                        count: product.reviewCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round heart button over product media.
class WishlistHeart extends StatelessWidget {
  const WishlistHeart({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 32,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: active ? 'Remove from wishlist' : 'Add to wishlist',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            boxShadow: c.shadowCard,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(
                CurvedAnimation(parent: a, curve: Curves.elasticOut),
              ),
              child: child,
            ),
            child: Icon(
              active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(active),
              size: size * 0.53,
              color: active ? c.wishlist : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add" button / quantity stepper, depending on whether this product's
/// variant is already a cart line.
class _CartAction extends ConsumerStatefulWidget {
  const _CartAction({required this.product});

  final CatalogProduct product;

  @override
  ConsumerState<_CartAction> createState() => _CartActionState();
}

class _CartActionState extends ConsumerState<_CartAction> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on AuthRequiredException {
      if (mounted) {
        AppSnack.show(
          context,
          'Sign in to add items to your cart.',
          actionLabel: 'Sign in',
          onAction: () => Navigator.pushNamed(context, logInScreenRoute),
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, cartErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final product = widget.product;
    final line = ref.watch(
      cartControllerProvider.select(
        (s) => s.valueOrNull?.items
            .where((l) => l.variantId == product.variantId)
            .firstOrNull,
      ),
    );
    final notifier = ref.read(cartControllerProvider.notifier);

    if (!product.buyable && line == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, a) => ScaleTransition(
        scale: a,
        alignment: Alignment.centerRight,
        child: FadeTransition(opacity: a, child: child),
      ),
      child: line == null
          ? Material(
              key: const ValueKey('add'),
              color: c.primary,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: c.primary.withValues(alpha: 0.4),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _busy
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _run(() => notifier.add(product.variantId));
                      },
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: _busy
                        ? SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.textOnPrimary,
                            ),
                          )
                        : Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: c.textOnPrimary,
                            semanticLabel: 'Add to cart',
                          ),
                  ),
                ),
              ),
            )
          : SizedBox(
              key: const ValueKey('stepper'),
              width: double.infinity,
              child: QuantityStepper(
                value: line.quantity,
                max: line.available,
                allowRemove: true,
                filled: true,
                busy: _busy,
                size: StepperSize.sm,
                onChanged: (next) => _run(
                  () => next <= 0
                      ? notifier.remove(line.id)
                      : notifier.setQuantity(line.id, next),
                ),
              ),
            ),
    );
  }
}

/// Two-column (three on tablets) product grid as a sliver, with the exact
/// row height cards need.
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({
    super.key,
    required this.products,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    this.onProductTap,
  });

  final List<CatalogProduct> products;
  final EdgeInsets padding;

  /// Overrides the default "open product page" tap.
  final void Function(CatalogProduct product)? onProductTap;

  static const double spacing = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width >= 600 ? 3 : 2;
          final tile = (width - spacing * (columns - 1)) / columns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: tile + kProductCardContentHeight + 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => CatalogProductCard(
                product: products[i],
                onTap: onProductTap == null
                    ? null
                    : () => onProductTap!(products[i]),
              ),
              childCount: products.length,
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal product rail (home sections, "You may also like").
class ProductRail extends StatelessWidget {
  const ProductRail({super.key, required this.products, this.cardWidth = 164});

  final List<CatalogProduct> products;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardWidth + kProductCardContentHeight + 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.smd),
        itemBuilder: (context, i) => SizedBox(
          width: cardWidth,
          child: CatalogProductCard(product: products[i]),
        ),
      ),
    );
  }
}
