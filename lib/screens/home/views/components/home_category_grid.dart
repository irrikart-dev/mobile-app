import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../models/catalog_category.dart';
import '../../../../route/route_constants.dart';
import 'category_art.dart';

/// Two rows of sage category tiles (4 per row) with the name underneath.
/// When there are more categories than fit, the last tile becomes "View all",
/// which jumps to the Categories tab via [onViewAll].
class HomeCategoryGrid extends StatelessWidget {
  const HomeCategoryGrid({
    super.key,
    required this.categories,
    required this.onViewAll,
  });

  final List<CatalogCategory> categories;
  final VoidCallback onViewAll;

  static const _columns = 4;
  static const _maxTiles = _columns * 2;
  static const _hGap = AppSpacing.smd;
  static const _vGap = AppSpacing.mdPlus;
  static const _labelGap = AppSpacing.sm;

  /// Labels wrap to two lines at most; text scaling is capped so the fixed
  /// row height below always holds them.
  static const _maxTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final overflow = categories.length > _maxTiles;
    final shown =
        overflow ? categories.take(_maxTiles - 1).toList() : categories;
    final count = shown.length + (overflow ? 1 : 0);
    final labelStyle = _labelStyle(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - AppSpacing.gutter * 2;
          final tile = (width - _hGap * (_columns - 1)) / _columns;
          // Two label lines, measured with the (clamped) text scale, plus a
          // couple of pixels of slack for font metrics rounding.
          final lineHeight = MediaQuery.textScalerOf(context)
                  .scale(labelStyle.fontSize!) *
              labelStyle.height!;
          final extent = tile + _labelGap + lineHeight * 2 + 4;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: _vGap,
              crossAxisSpacing: _hGap,
              mainAxisExtent: extent,
            ),
            itemBuilder: (context, i) {
              if (i >= shown.length) {
                return _Tile(
                  label: 'View all',
                  labelColor: context.colors.primary,
                  onTap: onViewAll,
                  art: const _ViewAllArt(),
                );
              }
              final category = shown[i];
              return _Tile(
                label: category.name,
                onTap: () => Navigator.pushNamed(
                  context,
                  productListScreenRoute,
                  arguments: category.id,
                ),
                art: CategoryArt(category: category),
              );
            },
          );
        },
      ),
    );
  }

  static TextStyle _labelStyle(BuildContext context) =>
      context.text.caption.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.onTap,
    required this.art,
    this.labelColor,
  });

  final String label;
  final VoidCallback onTap;
  final Widget art;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final style = HomeCategoryGrid._labelStyle(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 1, child: art),
            const SizedBox(height: HomeCategoryGrid._labelGap),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: labelColor == null
                  ? style
                  : style.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewAllArt extends StatelessWidget {
  const _ViewAllArt();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: AppRadius.lgAll,
      ),
      child: Center(
        child: Icon(
          Icons.grid_view_rounded,
          size: AppIconSize.lg,
          color: c.primary,
        ),
      ),
    );
  }
}
