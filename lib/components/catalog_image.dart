import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a catalogue image regardless of where it lives.
///
/// Products carried over from the IrriKart site ship as bundled assets;
/// products added in the admin dashboard carry a remote URL. Every catalogue
/// surface goes through this widget so neither case needs special-casing at
/// the call site, and both get the same placeholder and error treatment.
class CatalogImage extends StatelessWidget {
  const CatalogImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.isRemote,
  });

  /// Asset path (`assets/...`) or an absolute URL.
  final String? source;

  final BoxFit fit;

  /// Overrides the http:// sniffing when the caller already knows.
  final bool? isRemote;

  bool get _remote => isRemote ?? (source?.startsWith('http') ?? false);

  @override
  Widget build(BuildContext context) {
    final src = source;
    if (src == null || src.isEmpty) {
      return const _Placeholder(icon: Icons.image_not_supported_outlined);
    }

    if (_remote) {
      return CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        placeholder: (_, __) => const _Placeholder(),
        errorWidget: (_, __, ___) =>
            const _Placeholder(icon: Icons.broken_image_outlined),
      );
    }
    return Image.asset(
      src,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const _Placeholder(icon: Icons.broken_image_outlined),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                icon,
                size: 28,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
    );
  }
}
