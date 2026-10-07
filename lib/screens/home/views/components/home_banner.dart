import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../entry_point_tab.dart';
import '../../../../models/catalog_category.dart';
import '../../../../models/catalog_data.dart';
import '../../../../models/catalog_product.dart';
import '../../../../route/route_constants.dart';

/// What tapping a slide does. [categoryHint] is matched against the live
/// category list (id, slug or name) so the slide keeps working when the
/// admin dashboard renames or re-slugs a category.
sealed class _SlideAction {
  const _SlideAction();
}

class _OpenCategory extends _SlideAction {
  const _OpenCategory(this.categoryHint);
  final String categoryHint;
}

class _BulkQuote extends _SlideAction {
  const _BulkQuote();
}

class _Slide {
  const _Slide({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.action,
    this.deep = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String cta;

  /// Shown in the art disc when the catalogue has no photo to offer.
  final IconData icon;
  final _SlideAction action;

  /// A darker forest, for variety between neighbouring slides.
  final bool deep;
}

const _slides = [
  _Slide(
    eyebrow: 'READY TO INSTALL',
    title: 'Drip kits for\nevery farm',
    subtitle: 'Everything in one box',
    cta: 'Shop kits',
    icon: Icons.inventory_2_rounded,
    action: _OpenCategory('kit'),
  ),
  _Slide(
    eyebrow: 'SAVE WATER',
    title: 'Sprinklers for\neven coverage',
    subtitle: 'Micro, pop-up & impact',
    cta: 'Explore',
    icon: Icons.shower_rounded,
    action: _OpenCategory('sprinkler'),
    deep: true,
  ),
  _Slide(
    eyebrow: 'FOR FARMS & FPOs',
    title: 'Bulk pricing\nfor big orders',
    subtitle: 'Quotes on WhatsApp',
    cta: 'Get a quote',
    icon: Icons.request_quote_rounded,
    action: _BulkQuote(),
  ),
  _Slide(
    eyebrow: 'KEEP LINES CLEAN',
    title: 'Filters for\nclog-free drip',
    subtitle: 'Screen & disc filters',
    cta: 'Shop filters',
    icon: Icons.filter_alt_rounded,
    action: _OpenCategory('filter'),
    deep: true,
  ),
];

/// Home hero carousel: auto-advancing promo slides with a pill page
/// indicator. Each slide shows a real product photo from its category when
/// the catalogue has one. Every CTA does something real — opens a
/// category's product list or starts a WhatsApp bulk-quote chat.
class HomeBanner extends ConsumerStatefulWidget {
  const HomeBanner({super.key, required this.data});

  final CatalogData data;

  @override
  ConsumerState<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends ConsumerState<HomeBanner> {
  static const _interval = Duration(seconds: 5);

  final _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _slides.length,
        duration: AppDurations.slow,
        curve: AppCurves.emphasized,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  CatalogCategory? _resolve(String hint) {
    final h = hint.toLowerCase();
    for (final c in widget.data.categories) {
      if (c.id.toLowerCase().contains(h) ||
          c.slug.toLowerCase().contains(h) ||
          c.name.toLowerCase().contains(h)) {
        return c;
      }
    }
    return null;
  }

  /// A real product photo for the slide's category, preferring something in
  /// stock. Null for the bulk slide, or when nothing there has an image.
  CatalogProduct? _heroProduct(_Slide slide) {
    if (slide.action case _OpenCategory(:final categoryHint)) {
      final category = _resolve(categoryHint);
      if (category == null) return null;
      final withImage = widget.data
          .productsInCategory(category.id)
          .where((p) => p.displayImage?.isNotEmpty ?? false)
          .toList();
      return withImage.where((p) => p.buyable).firstOrNull ??
          withImage.firstOrNull;
    }
    return null;
  }

  void _onTap(_Slide slide) {
    switch (slide.action) {
      case _OpenCategory(:final categoryHint):
        final category = _resolve(categoryHint);
        if (category != null) {
          Navigator.pushNamed(
            context,
            productListScreenRoute,
            arguments: category.id,
          );
        } else {
          // Category not in the live catalogue — the Categories tab is the
          // next best place to land.
          ref.read(entryTabIndexProvider.notifier).state = 1;
        }
      case _BulkQuote():
        openWhatsAppSupport(
          context,
          message: 'Hi IrriKart, I would like a quote for a bulk order.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        SizedBox(
          height: 184,
          child: NotificationListener<ScrollStartNotification>(
            // A manual swipe resets the auto-advance clock.
            onNotification: (n) {
              if (n.dragDetails != null) _restartTimer();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: _SlideCard(
                  slide: _slides[i],
                  product: _heroProduct(_slides[i]),
                  onTap: () => _onTap(_slides[i]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: AppDurations.normal,
                curve: AppCurves.standard,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? c.primary : c.border,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.product,
    required this.onTap,
  });

  final _Slide slide;
  final CatalogProduct? product;
  final VoidCallback onTap;

  static const double _art = 128;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Forest in light mode. In dark mode the bright brand green is too loud
    // for a full-bleed block, so it is pulled down to a deep green.
    final forest = context.isDark ? _darken(c.primary, 0.26) : c.primary;
    final base = slide.deep ? _darken(forest, 0.05) : forest;
    final deeper = _darken(base, 0.09);
    final fg = context.isDark ? c.textPrimary : c.textOnPrimary;

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlAll,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, deeper],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // One soft halo behind the art — depth without clutter.
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.mdPlus,
              top: 0,
              bottom: 0,
              child: Center(
                child: _SlideArt(
                  size: _art,
                  product: product,
                  icon: slide.icon,
                  disc: fg,
                  shade: deeper,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mdPlus,
                AppSpacing.mdPlus,
                _art + AppSpacing.mdPlus + AppSpacing.smd,
                AppSpacing.mdPlus,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.overline.copyWith(
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.h2.copyWith(color: fg),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    slide.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(
                      color: fg.withValues(alpha: 0.78),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.cta,
                          style: context.text.label.copyWith(color: deeper),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: AppIconSize.xs + 2,
                          color: deeper,
                        ),
                      ],
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
}

/// A light disc holding the product photo — its white studio background
/// multiplied away into the disc — or the slide's glyph when there's no
/// photo to show.
class _SlideArt extends StatelessWidget {
  const _SlideArt({
    required this.size,
    required this.product,
    required this.icon,
    required this.disc,
    required this.shade,
  });

  final double size;
  final CatalogProduct? product;
  final IconData icon;
  final Color disc;
  final Color shade;

  @override
  Widget build(BuildContext context) {
    final glyph = Center(
      child: Icon(icon, size: size * 0.36, color: shade),
    );
    final p = product;
    final src = p?.displayImage;

    Widget content = glyph;
    if (p != null && src != null) {
      final image = p.hasRemoteImage
          ? CachedNetworkImage(
              imageUrl: src,
              fit: BoxFit.contain,
              color: disc,
              colorBlendMode: BlendMode.multiply,
              placeholder: (_, __) => glyph,
              errorWidget: (_, __, ___) => glyph,
            )
          : Image.asset(
              src,
              fit: BoxFit.contain,
              color: disc,
              colorBlendMode: BlendMode.multiply,
              frameBuilder: (context, child, frame, sync) =>
                  frame == null && !sync ? glyph : child,
              errorBuilder: (_, __, ___) => glyph,
            );
      content = Padding(
        padding: EdgeInsets.all(size * 0.13),
        child: image,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: disc,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: shade.withValues(alpha: 0.4),
            offset: const Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// Same hue, lower lightness — keeps the gradient brand-true in both themes.
Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}
