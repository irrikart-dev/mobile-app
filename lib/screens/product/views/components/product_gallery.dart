import 'package:flutter/material.dart';

import '../../../../components/catalog_image.dart';
import '../../../../components/ui/ui.dart';
import 'fullscreen_gallery.dart';

/// Full-bleed PDP gallery: swipeable photos floating on a sage field, with
/// pill page dots. The content sheet overlaps its bottom [overlap] pixels, so
/// the photos and dots sit above that band. Tapping a photo opens
/// [FullscreenGallery] at that page.
///
/// Catalogue photos are shot on white; in light mode they're multiplied into
/// the sage so the product appears to sit directly on the page. Dark mode
/// can't do that without muddying the photo, so it shows the photo on its
/// own rounded plate instead.
class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.images,
    required this.isRemote,
    required this.height,
    this.overlap = 0,
    this.dimmed = false,
  });

  final List<String> images;
  final bool isRemote;

  /// Total height, including the status-bar area it extends under.
  final double height;

  /// How much of the bottom is covered by the content sheet.
  final double overlap;

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

  /// Bundled `assets/` paths are always local, whatever the product says.
  bool _isRemote(String? src) =>
      widget.isRemote && !(src?.startsWith('assets/') ?? false);

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
    final dark = context.isDark;
    final images = widget.images;
    final multi = images.length > 1;
    final top = MediaQuery.paddingOf(context).top;
    const dotsBand = AppSpacing.xlPlus;

    Widget photo(String? src) {
      Widget image = CatalogImage(
        source: src,
        isRemote: _isRemote(src),
        fit: BoxFit.contain,
      );
      image = dark
          // Knock the white plate back a touch so it doesn't glare.
          ? ClipRRect(
              borderRadius: AppRadius.lgAll,
              child: ColorFiltered(
                colorFilter:
                    ColorFilter.mode(c.textPrimary, BlendMode.multiply),
                child: image,
              ),
            )
          : ColorFiltered(
              colorFilter: ColorFilter.mode(c.tint, BlendMode.multiply),
              child: image,
            );
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          top + AppSpacing.xxxl,
          AppSpacing.xl,
          widget.overlap + dotsBand,
        ),
        child: Center(
          child: AnimatedOpacity(
            opacity: widget.dimmed ? 0.5 : 1,
            duration: AppDurations.normal,
            child: image,
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: ColoredBox(
        color: c.tint,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: images.isNotEmpty,
              label: 'Product photos, tap to view full screen',
              child: GestureDetector(
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
            ),
            if (multi)
              Positioned(
                left: 0,
                right: 0,
                bottom: widget.overlap + AppSpacing.mdPlus,
                child: Center(
                  child: GalleryDots(
                    count: images.length,
                    index: _page,
                    inactiveColor: c.primary.withValues(alpha: 0.18),
                  ),
                ),
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
            width: i == index ? 22 : 7,
            height: 7,
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
