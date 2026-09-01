import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors_extension.dart';
import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/shadow_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/theme/tokens/typography_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../models/catalog_product.dart';
import '../../models/wishlist_state.dart';
import '../catalog_image.dart';

/// A product card for grids: image, wishlist heart, name, rating, price.
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
                  ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: CatalogImage(
                        source: product.displayImage,
                        isRemote: product.hasRemoteImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (product.discountPercent > 0)
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: _Badge(
                        text: '${product.discountPercent}% OFF',
                        color: ext.discount,
                      ),
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
                  if (!product.inStock)
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
                AppSpacing.sm,
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
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          formatInr(product.price),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.price(
                            theme.colorScheme.primary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (product.discountPercent > 0) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            formatInr(product.mrp),
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.strikePrice(ext.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
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
        style: AppTypography.overline(Colors.white, fontSize: 9.5),
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
