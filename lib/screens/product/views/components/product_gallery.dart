import 'package:flutter/material.dart';

import '../../../../components/catalog_image.dart';
import '../../../../components/ui/ui.dart';
import 'fullscreen_gallery.dart';

/// Full-bleed, square PDP gallery: swipeable photos on a sunken surface, an
/// animated pill page indicator and an "n / total" counter. Tapping a photo
/// opens [FullscreenGallery] at that page.
///
/// Falls back to a single image when the product predates the multi-image
/// gallery (bundled offline fixtures, or a product without extra angles).
class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.images,
    required this.isRemote,
    this.dimmed = false,
  });

  final List<String> images;
  final bool isRemote;

  /// Fades the photo slightly — used when the selected option is out of stock.
  final bool dimmed;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(covariant ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.images.length && widget.images.isNotEmpty) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openViewer() async {
    if (widget.images.isEmpty) return;
    final page = await FullscreenGallery.open(
      context,
      images: widget.images,
      isRemote: widget.isRemote,
      initialPage: _page,
    );
    if (!mounted || page == null || page == _page) return;
    if (_controller.hasClients) _controller.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final images = widget.images;
    final multi = images.length > 1;

    Widget photo(String? src) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl + AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: AnimatedOpacity(
            opacity: widget.dimmed ? 0.55 : 1,
            duration: AppDurations.normal,
            child: CatalogImage(
              source: src,
              isRemote: widget.isRemote,
              fit: BoxFit.contain,
            ),
          ),
        );

    return AspectRatio(
      aspectRatio: 1,
      child: ColoredBox(
        color: c.surfaceSunken,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: images.isEmpty ? null : _openViewer,
              child: multi
                  ? PageView.builder(
                      controller: _controller,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => photo(images[i]),
                    )
                  : photo(images.isEmpty ? null : images.first),
            ),
            if (multi)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.md,
                child: Center(
                  child: GalleryDots(count: images.length, index: _page),
                ),
              ),
            if (multi)
              Positioned(
                right: AppSpacing.gutter,
                bottom: AppSpacing.smd,
                child: _Counter(index: _page, total: images.length),
              ),
            if (images.isNotEmpty)
              Positioned(
                left: AppSpacing.gutter,
                bottom: AppSpacing.smd,
                child: _ZoomHint(onTap: _openViewer),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated pill page indicator — the active page stretches into a pill.
class GalleryDots extends StatelessWidget {
  const GalleryDots({
    super.key,
    required this.count,
    required this.index,
    this.activeColor,
    this.inactiveColor,
  });

  final int count;
  final int index;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? (activeColor ?? c.primary)
                  : (inactiveColor ?? c.borderStrong),
              borderRadius: AppRadius.pillAll,
            ),
          ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: c.border),
      ),
      child: Text(
        '${index + 1} / $total',
        style: context.text.badge.copyWith(color: c.textSecondary),
      ),
    );
  }
}

class _ZoomHint extends StatelessWidget {
  const _ZoomHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'View full screen',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: c.border),
          ),
          child: Icon(
            Icons.zoom_out_map_rounded,
            size: 16,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}
