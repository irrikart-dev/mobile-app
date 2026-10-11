import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/catalog_product.dart';

/// A live-shaped product (with ids and variants) for model tests.
CatalogProduct product(
  String slug, {
  String? id,
  num price = 100,
  double rating = 4.5,
  int reviewCount = 10,
  bool inStock = true,
  int stock = 20,
  int? available,
  String? brandId,
  String? brandName,
  List<Map<String, dynamic>>? variants,
}) {
  return CatalogProduct.fromJson({
    'id': id ?? 'p_$slug',
    'variantId': 'v_$slug',
    'slug': slug,
    'name': 'Product $slug',
    'category': 'cat',
    'imageUrl': 'https://img/$slug.jpg',
    'unit': 'piece',
    'price': price,
    'rating': rating,
    'reviewCount': reviewCount,
    'inStock': inStock,
    'stockQty': stock,
    'brandId': brandId,
    'brandName': brandName,
    'variants': variants ??
        [
          {
            'id': 'v_$slug',
            'sku': 'SKU-$slug',
            'unit': 'piece',
            'price': price,
            'stockQty': stock,
            'available': available ?? stock,
          },
        ],
  });
}

CatalogData catalog(List<CatalogProduct> products) =>
    CatalogData.forTesting(categories: const [], products: products);
