import 'package:flutter/material.dart';

import '../../../../components/catalog_image.dart';
import '../../../../components/ui/ui.dart';
import 'product_gallery.dart';

/// Immersive photo viewer: swipe between photos, pinch or double-tap to
/// zoom, drag down (or tap close) to dismiss. Pops with the page the viewer
/// was on so the inline gallery can follow.
class FullscreenGallery extends StatefulWidget {
  const FullscreenGallery({
    super.key,
    required this.images,
    required this.isRemote,
    this.initialPage = 0,
  });

  final List<String> images;
  final bool isRemote;
  final int initialPage;

  static Future<int?> open(
    BuildContext context, {
    required List<String> images,
    required bool isRemote,
    int initialPage = 0,
  }) {
    return Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: AppDurations.normal,
        reverseTransitionDuration: AppDurations.fast,
        pageBuilder: (_, __, ___) => FullscreenGallery(
          images: images,
          isRemote: isRemote,
          initialPage: initialPage,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: AppCurves.standard),
          child: child,
        ),
      ),
    );
  }

  @override
  State<FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<FullscreenGallery> {
  late final PageController _pages =
      PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;
  final Map<int, TransformationController> _zoom = {};
  bool _zoomed = false;
  double _drag = 0;
  Offset _tapPoint = Offset.zero;

  TransformationController _zoomFor(int i) => _zoom.putIfAbsent(i, () {
        final ctrl = TransformationController();
        ctrl.addListener(() {
          if (i != _page) return;
          final zoomed = ctrl.value.getMaxScaleOnAxis() > 1.01;
          if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
        });
        return ctrl;
      });

  @override
  void dispose() {
    _pages.dispose();
    for (final ctrl in _zoom.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_page);

  void _toggleZoom() {
    final ctrl = _zoomFor(_page);
    if (_zoomed) {
      ctrl.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final p = _tapPoint;
    // Scale about the tapped point: x' = s·x + t, with t = -p·(s - 1).
    ctrl.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, -p.dx * (scale - 1))
      ..setEntry(1, 3, -p.dy * (scale - 1));
  }

  @override
  Widget build(BuildContext context) {
    // Viewer chrome sits on true black in both themes, so it's always white.
    const fg = Colors.white;
    final total = widget.images.length;
    final dismissProgress = (_drag.abs() / 300).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onVerticalDragUpdate:
            _zoomed ? null : (d) => setState(() => _drag += d.delta.dy),
        onVerticalDragEnd: _zoomed
            ? null
            : (d) {
                if (_drag.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
                  _close();
                } else {
                  setState(() => _drag = 0);
                }
              },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo viewer backdrop — intentionally true black so photos
            // read at their real contrast in both themes.
            ColoredBox(
              color: Colors.black.withValues(alpha: 1 - dismissProgress * 0.7),
            ),
            Transform.translate(
              offset: Offset(0, _drag),
              child: PageView.builder(
                controller: _pages,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: total,
                onPageChanged: (i) {
                  _zoomFor(_page).value = Matrix4.identity();
                  setState(() {
                    _page = i;
                    _zoomed = false;
                  });
                },
                itemBuilder: (context, i) => GestureDetector(
                  onDoubleTapDown: (d) => _tapPoint = d.localPosition,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _zoomFor(i),
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: CatalogImage(
                        source: widget.images[i],
                        isRemote: widget.isRemote &&
                            !widget.images[i].startsWith('assets/'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: AnimatedOpacity(
                opacity: 1 - dismissProgress,
                duration: AppDurations.instant,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: AppSpacing.sm),
                          if (total > 1)
                            Text(
                              '${_page + 1} of $total',
                              style: context.text.label.copyWith(color: fg),
                            ),
                          const Spacer(),
                          _ViewerButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Close',
                            onTap: _close,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (total > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: GalleryDots(
                          count: total,
                          index: _page,
                          activeColor: fg,
                          inactiveColor: fg.withValues(alpha: 0.35),
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

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fg.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}
