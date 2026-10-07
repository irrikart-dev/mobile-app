import 'package:flutter/material.dart';

import '../../../../components/catalog_image.dart';
import '../../../../components/ui/ui.dart';
import '../../../../models/catalog_category.dart';
import '../../../../route/route_constants.dart';

/// Two rows of category tiles (4 per row). When there are more categories
/// than fit, the last tile becomes "View all", which jumps to the
/// Categories tab via [onViewAll].
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

  @override
  Widget build(BuildContext context) {
    final overflow = categories.length > _maxTiles;
    final shown =
        overflow ? categories.take(_maxTiles - 1).toList() : categories;
    final count = shown.length + (overflow ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.smd,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, i) {
        if (i >= shown.length) return _ViewAllTile(onTap: onViewAll);
        final category = shown[i];
        return _CategoryTile(
          category: category,
          onTap: () => Navigator.pushNamed(
            context,
            productListScreenRoute,
            arguments: category.id,
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final CatalogCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: AppRadius.lgAll,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.smAll,
                child: CatalogImage(
                  source: category.displayImage,
                  isRemote: category.hasRemoteImage,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Text(
            category.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.caption.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewAllTile extends StatelessWidget {
  const _ViewAllTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: c.border),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: AppIconSize.lg,
                color: c.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Text(
            'View all',
            textAlign: TextAlign.center,
            style: context.text.caption.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
