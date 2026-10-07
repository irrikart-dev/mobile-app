import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../entry_point_tab.dart';
import '../../../../models/catalog_category.dart';
import '../../../../route/route_constants.dart';

enum _SlideTone { primary, water, deep }

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
    required this.tone,
    required this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final _SlideTone tone;
  final _SlideAction action;
}

const _slides = [
  _Slide(
    eyebrow: 'READY TO INSTALL',
    title: 'Complete drip kits\nfor every farm',
    subtitle: 'Everything in one box, from ₹2,209',
    cta: 'Shop kits',
    icon: Icons.grass_rounded,
    tone: _SlideTone.primary,
    action: _OpenCategory('kit'),
  ),
  _Slide(
    eyebrow: 'EVEN COVERAGE',
    title: 'Sprinklers that\nsave water',
    subtitle: 'Impact, rotary & pop-up sprinklers',
    cta: 'Explore',
    icon: Icons.water_drop_rounded,
    tone: _SlideTone.water,
    action: _OpenCategory('sprinkler'),
  ),
  _Slide(
    eyebrow: 'FOR FARMS & FPOs',
    title: 'Buying in bulk?\nGet a quote',
    subtitle: 'Special pricing on large orders',
    cta: 'Chat with us',
    icon: Icons.request_quote_rounded,
    tone: _SlideTone.deep,
    action: _BulkQuote(),
  ),
  _Slide(
    eyebrow: 'KEEP LINES CLEAN',
    title: 'Filters for\nclog-free drip',
    subtitle: 'Screen, disc & sand media filters',
    cta: 'Shop filters',
    icon: Icons.filter_alt_rounded,
    tone: _SlideTone.primary,
    action: _OpenCategory('filter'),
  ),
];

/// Home hero carousel: auto-advancing promo slides with a pill page
/// indicator. Every slide's CTA does something real — opens a category's
/// product list or starts a WhatsApp bulk-quote chat.
class HomeBanner extends ConsumerStatefulWidget {
  const HomeBanner({super.key, required this.categories});

  final List<CatalogCategory> categories;

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
    for (final c in widget.categories) {
      if (c.id.toLowerCase().contains(h) ||
          c.slug.toLowerCase().contains(h) ||
          c.name.toLowerCase().contains(h)) {
        return c;
      }
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
          height: 172,
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
                width: i == _page ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? c.primary : c.borderStrong,
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
  const _SlideCard({required this.slide, required this.onTap});

  final _Slide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (base, fg) = switch (slide.tone) {
      _SlideTone.primary => (c.primary, c.textOnPrimary),
      _SlideTone.water => (c.secondary, c.textOnPrimary),
      _SlideTone.deep => (_darken(c.primary, 0.16), c.textOnPrimary),
    };
    final deeper = _darken(base, 0.12);

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, deeper],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Soft decorative rings behind the icon.
            Positioned(
              right: -36,
              top: -28,
              child: _Ring(size: 180, color: fg.withValues(alpha: 0.08)),
            ),
            Positioned(
              right: 24,
              bottom: -48,
              child: _Ring(size: 120, color: fg.withValues(alpha: 0.06)),
            ),
            Positioned(
              right: AppSpacing.mdPlus,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(slide.icon, size: 36, color: fg),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mdPlus,
                AppSpacing.md,
                112,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.eyebrow,
                    style: context.text.overline.copyWith(
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.h3.copyWith(color: fg),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    slide.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(
                      color: fg.withValues(alpha: 0.88),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.smd,
                      vertical: 7,
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
                          size: AppIconSize.xs,
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

/// Same hue, lower lightness — keeps the gradient brand-true in both themes.
Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
