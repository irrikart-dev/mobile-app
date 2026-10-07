import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/utils/context_ext.dart';

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
    this.color,
    this.colorBlendMode,
  });

  /// Asset path (`assets/...`) or an absolute URL.
  final String? source;

  final BoxFit fit;

  /// Overrides the http:// sniffing when the caller already knows.
  final bool? isRemote;

  /// Optional blend, e.g. `BlendMode.multiply` with the sage tint so a
  /// product shot's white studio background melts into its tile.
  final Color? color;
  final BlendMode? colorBlendMode;

  bool get _remote => isRemote ?? (source?.startsWith('http') ?? false);

  @override
  Widget build(BuildContext context) {
    final src = source;
    if (src == null || src.isEmpty) return const _Placeholder();

    if (_remote) {
      return CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        color: color,
        colorBlendMode: colorBlendMode,
        placeholder: (_, __) => const _Placeholder(),
        errorWidget: (_, __, ___) => const _Placeholder(),
      );
    }
    return Image.asset(
      src,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: (_, __, ___) => const _Placeholder(),
    );
  }
}

/// Plain sage block — no "broken image" glyph; the tile shape alone reads
/// as "image goes here".
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.colors.tint, child: const SizedBox.expand());
}
