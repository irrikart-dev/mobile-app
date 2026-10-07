import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Floating PDP top bar. Over the gallery it's just round buttons on soft
/// discs; once the gallery scrolls away ([progress] → 1) it fades into a
/// solid bar with the product name, and the discs settle into sage.
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
    // Over the sage gallery the discs are page-coloured; on the solid bar
    // they become sage so they still read as buttons.
    final disc = Color.lerp(c.background, c.tint, t)!;

    Widget button({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      Color? color,
      int badge = 0,
    }) =>
        Material(
          color: disc,
          shape: const CircleBorder(),
          child: AppIconButton(
            icon: icon,
            tooltip: tooltip,
            color: color,
            badgeCount: badge,
            iconSize: AppIconSize.md - 1,
            onPressed: onPressed,
          ),
        );

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        top + AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: t),
        border: Border(
          bottom: BorderSide(color: c.divider.withValues(alpha: t)),
        ),
      ),
      child: Row(
        children: [
          button(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: onBack,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Opacity(
              opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.h3,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          button(
            icon: wishlisted
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: wishlisted ? c.wishlist : null,
            tooltip: wishlisted ? 'Remove from wishlist' : 'Add to wishlist',
            onPressed: onWishlist,
          ),
          const SizedBox(width: AppSpacing.smd - 2),
          button(
            icon: Icons.shopping_bag_outlined,
            tooltip: 'Cart',
            badge: cartCount,
            onPressed: onCart,
          ),
        ],
      ),
    );
  }
}
