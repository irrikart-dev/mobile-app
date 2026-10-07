import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Floating PDP top bar. Over the gallery it's just round buttons on
/// translucent surfaces; once the gallery scrolls away ([progress] → 1) it
/// fades into a solid bar with the product name and a hairline.
class PdpTopBar extends StatelessWidget {
  const PdpTopBar({
    super.key,
    required this.progress,
    required this.title,
    required this.onBack,
    required this.wishlisted,
    required this.onWishlist,
    required this.cartCount,
    required this.onCart,
  });

  final double progress;
  final String title;
  final VoidCallback onBack;
  final bool wishlisted;
  final VoidCallback onWishlist;
  final int cartCount;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    final t = progress.clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        top + AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: t),
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: t)),
        ),
      ),
      child: Row(
        children: [
          _RoundButton(
            solid: t,
            child: AppIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Opacity(
              opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.title,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _RoundButton(
            solid: t,
            child: AppIconButton(
              icon: wishlisted
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: wishlisted ? c.wishlist : null,
              tooltip: wishlisted ? 'Remove from wishlist' : 'Add to wishlist',
              onPressed: onWishlist,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoundButton(
            solid: t,
            child: AppIconButton(
              icon: Icons.shopping_bag_outlined,
              tooltip: 'Cart',
              badgeCount: cartCount,
              onPressed: onCart,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gives a button a translucent disc + soft shadow while it floats over the
/// photo, dissolving as the bar turns solid.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.solid, required this.child});

  final double solid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final float = 1 - solid;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface.withValues(alpha: 0.92 * float),
        boxShadow: float > 0.5 ? c.shadowCard : null,
      ),
      child: child,
    );
  }
}
