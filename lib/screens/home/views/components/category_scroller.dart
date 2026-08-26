import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../../models/catalog_category.dart';
import '../../../../route/route_constants.dart';

/// Horizontal row of circular category thumbnails. Matches the reference
/// theme's `home-cat-scroll` / `home-cat-item`.
class CategoryScroller extends StatelessWidget {
  const CategoryScroller({super.key, required this.categories});

  final List<CatalogCategory> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final category = categories[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              productListScreenRoute,
              arguments: category.id,
            ),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      image: DecorationImage(
                        image: AssetImage(category.image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
