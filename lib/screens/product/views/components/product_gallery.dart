import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../components/catalog_image.dart';
import '../../../../core/theme/tokens/radius_tokens.dart';

/// PDP media viewer: swipeable photo gallery plus, when the product has one,
/// a "Watch video" chip that hands off to YouTube. Falls back to a single
/// image when the product predates the multi-image gallery (bundled offline
/// fixtures, or a product the admin hasn't added extra angles to yet).
class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.images,
    required this.isRemote,
    this.videoUrl,
  });

  final List<String> images;
  final bool isRemote;
  final String? videoUrl;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openVideo() async {
    final url = widget.videoUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final theme = Theme.of(context);

    return Column(
      children: [
        ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: ColoredBox(
            color: theme.colorScheme.primary.withValues(alpha: 0.07),
            child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: images.length <= 1
                    ? CatalogImage(
                        source: images.isEmpty ? null : images.first,
                        isRemote: widget.isRemote,
                        fit: BoxFit.contain,
                      )
                    : PageView.builder(
                        controller: _controller,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) => CatalogImage(
                          source: images[i],
                          isRemote: widget.isRemote,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (images.length > 1 || widget.videoUrl != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (images.length > 1)
                for (var i = 0; i < images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.25),
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
              if (widget.videoUrl != null) ...[
                if (images.length > 1) const SizedBox(width: 12),
                ActionChip(
                  avatar: const Icon(Icons.play_circle_fill, size: 18),
                  label: const Text('Watch video'),
                  onPressed: _openVideo,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
