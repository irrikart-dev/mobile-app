import 'package:flutter/material.dart';

import '../../../../components/app_kicker.dart';
import '../../../../components/product/catalog_product_card.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../../models/catalog_product.dart';
import '../../../../route/route_constants.dart';

/// A kicker + heading + horizontally-scrolling row of product cards.
/// The recurring "home-section" pattern from the reference theme.
class ProductSection extends StatelessWidget {
  const ProductSection({
    super.key,
    required this.kicker,
    required this.title,
    required this.products,
  });

  final String kicker;
  final String title;
  final List<CatalogProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppKicker(kicker),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final product = products[i];
              return SizedBox(
                width: 168,
                child: CatalogProductCard(
                  product: product,
                  onTap: () => Navigator.pushNamed(
                    context,
                    productDetailsScreenRoute,
                    arguments: product.slug,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
