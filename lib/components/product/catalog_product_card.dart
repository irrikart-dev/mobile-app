import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors_extension.dart';
import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/shadow_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart_state.dart';
import '../../models/catalog_product.dart';
import '../../models/wishlist_state.dart';
import '../catalog_image.dart';

/// A product card for grids: full-bleed photo, wishlist heart, name,
/// rating, price, and an inline add-to-cart control that becomes a quantity
/// stepper once the item is in the cart — so bumping quantity from a grid
/// never requires a trip to the cart screen.
///
/// The one card every catalogue-facing screen (home, categories, product
/// list, search, wishlist) uses, so the product grid reads consistently
/// everywhere. Content below the image is deliberately kept to a single
/// text line each (name / rating / price) so the card's height is
/// predictable and never depends on how long a product's name happens to
/// be — the failure mode that caused real overflow on-device.
class CatalogProductCard extends ConsumerWidget {
  const CatalogProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;
    final isWishlisted = ref.watch(
      wishlistControllerProvider.select((s) => s.contains(product.slug)),
    );
    final cartLine = ref.watch(
      cartControllerProvider.select(
        (s) => s.valueOrNull?.items
            .cast<CartLine?>()
            .firstWhere((l) => l?.variantId == product.variantId, orElse: () => null),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          boxShadow: AppShadows.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CatalogImage(
                    source: product.displayImage,
                    isRemote: product.hasRemoteImage,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _WishlistButton(
                      isActive: isWishlisted,
                      onTap: () => ref
                          .read(wishlistControllerProvider.notifier)
                          .toggle(product.slug),
                    ),
                  ),
                  if (!product.buyable)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: _Badge(
                            text: 'OUT OF STOCK',
                            color: Colors.black.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: ext.warning),
                      const SizedBox(width: 2),
                      Text(
                        '${product.rating}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ext.muted,
                        ),
                      ),
                      Text(
                        ' (${product.reviewCount})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatInr(product.price),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Divider(height: AppSpacing.sm),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: cartLine == null
                    ? _AddButton(product: product)
                    : _QtyStepper(product: product, line: cartLine),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends ConsumerStatefulWidget {
  const _AddButton({required this.product});

  final CatalogProduct product;

  @override
  ConsumerState<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<_AddButton> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .add(widget.product.variantId, quantity: 1);
    } on AuthRequiredException {
      // Silently no-op here — the grid isn't the place to bounce to sign-in;
      // the product/cart screens already handle that case explicitly.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cartErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: widget.product.buyable && !_busy ? _add : null,
      icon: _busy
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.shopping_bag_outlined, size: 15),
      label: Text(widget.product.buyable ? 'Add to cart' : 'Unavailable'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    );
  }
}

class _QtyStepper extends ConsumerStatefulWidget {
  const _QtyStepper({required this.product, required this.line});

  final CatalogProduct product;
  final CartLine line;

  @override
  ConsumerState<_QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends ConsumerState<_QtyStepper> {
  bool _busy = false;

  Future<void> _change(int delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    final notifier = ref.read(cartControllerProvider.notifier);
    try {
      final next = widget.line.quantity + delta;
      if (next <= 0) {
        await notifier.remove(widget.line.id);
      } else {
        await notifier.setQuantity(widget.line.id, next);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cartErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: _busy ? null : () => _change(-1),
          ),
          Text(
            '${widget.line.quantity}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: _busy || widget.line.quantity >= widget.line.available
                ? null
                : () => _change(1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? theme.disabledColor
              : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.smAll),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  const _WishlistButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: AppShadows.sm,
        ),
        child: Icon(
          isActive ? Icons.favorite : Icons.favorite_border,
          size: 15,
          color: isActive ? Colors.redAccent : Colors.black54,
        ),
      ),
    );
  }
}
