import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../models/catalog_category.dart';

/// A fitting glyph for a category, picked from keywords in its name / slug.
/// Order matters: the more specific words ("safety", "home") are checked
/// before the generic ones ("valve", "irrigation").
IconData categoryIcon(CatalogCategory category) {
  final key = '${category.name} ${category.slug}'.toLowerCase();
  bool has(List<String> words) => words.any(key.contains);

  if (has(['safety', 'pressure', 'air release'])) {
    return Icons.health_and_safety_rounded;
  }
  if (has(['sprinkler', 'rain gun', 'raingun'])) return Icons.shower_rounded;
  if (has(['mist', 'fog'])) return Icons.cloud_rounded;
  if (has(['filter'])) return Icons.filter_alt_rounded;
  if (has(['valve', 'control', 'timer'])) return Icons.tune_rounded;
  if (has(['pump', 'motor'])) return Icons.settings_input_component_rounded;
  if (has(['pipe', 'tube', 'fitting', 'saddle', 'connector'])) {
    return Icons.plumbing_rounded;
  }
  if (has(['kit'])) return Icons.inventory_2_rounded;
  if (has(['home', 'garden', 'terrace'])) return Icons.yard_rounded;
  if (has(['landscape', 'lawn', 'turf'])) return Icons.park_rounded;
  if (has(['tool'])) return Icons.handyman_rounded;
  if (has(['fertili', 'nutrient'])) return Icons.eco_rounded;
  if (has(['seed'])) return Icons.grass_rounded;
  if (has(['drip', 'irrigation', 'emitter', 'dripper'])) {
    return Icons.water_drop_rounded;
  }
  return Icons.category_rounded;
}

/// Fills its box with a soft sage tile showing the category's photo — or,
/// while that loads / when there is none / when it fails, the category's
/// glyph, so a tile is never blank.
///
/// In light mode the photo is multiplied onto the sage, so the white studio
/// backgrounds of product shots melt into the tile instead of sitting on it
/// as a white square. In dark mode the photo fills the tile.
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.category,
    this.radius = AppRadius.lgAll,
    this.iconSize,
    this.imagePadding = const EdgeInsets.all(AppSpacing.sm),
  });

  final CatalogCategory category;
  final BorderRadius radius;
  /// Defaults to about a third of the tile.
  final double? iconSize;
  final EdgeInsets imagePadding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    final src = category.displayImage;

    final glyph = LayoutBuilder(
      builder: (context, box) => Center(
        child: Icon(
          categoryIcon(category),
          size: iconSize ?? (box.biggest.shortestSide * 0.36).clamp(18, 56),
          color: c.onPrimarySoft,
        ),
      ),
    );

    // On the dark canvas the photo can't melt into the tile, so it fills the
    // whole tile instead (square shots, so nothing is cropped) — one photo
    // tile rather than a white print sitting inside a dark one.
    Widget framed(Widget image) => dark
        ? image
        : Padding(padding: imagePadding, child: image);
    final fit = dark ? BoxFit.cover : BoxFit.contain;

    final Color? blend = dark ? null : c.tint;
    const blendMode = BlendMode.multiply;

    Widget content;
    if (src == null || src.isEmpty) {
      content = glyph;
    } else if (category.hasRemoteImage) {
      content = CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        color: blend,
        colorBlendMode: blendMode,
        imageBuilder: (context, provider) => framed(
          Image(
            image: provider,
            fit: fit,
            color: blend,
            colorBlendMode: blendMode,
          ),
        ),
        placeholder: (_, __) => glyph,
        errorWidget: (_, __, ___) => glyph,
      );
    } else {
      content = Image.asset(
        src,
        fit: fit,
        color: blend,
        colorBlendMode: blendMode,
        frameBuilder: (context, child, frame, sync) =>
            frame == null && !sync ? glyph : framed(child),
        errorBuilder: (_, __, ___) => glyph,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: c.tint,
        child: SizedBox.expand(child: content),
      ),
    );
  }
}
