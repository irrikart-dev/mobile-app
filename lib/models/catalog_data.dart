import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_category.dart';
import 'catalog_product.dart';

/// Loads the mock catalogue bundled at `assets/mock/`.
///
/// Stands in for `features/catalog/data` until the real repository (backed
/// by the live API, with a mock/real datasource switch) is built. Every
/// screen should read catalogue data through the providers below, not by
/// reaching into this class directly, so that swap is a one-file change.
class CatalogData {
  const CatalogData._({required this.categories, required this.products});

  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;

  static Future<CatalogData> load() async {
    final categoriesJson = await rootBundle.loadString(
      'assets/mock/categories.json',
    );
    final productsJson = await rootBundle.loadString(
      'assets/mock/products.json',
    );

    final categories = (jsonDecode(categoriesJson) as List)
        .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    final products = (jsonDecode(productsJson) as List)
        .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
        .toList();

    return CatalogData._(categories: categories, products: products);
  }

  CatalogCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  CatalogProduct? productBySlug(String slug) {
    for (final p in products) {
      if (p.slug == slug) return p;
    }
    return null;
  }

  List<CatalogProduct> productsInCategory(String categoryId) =>
      products.where((p) => p.category == categoryId).toList();

  List<CatalogProduct> get featuredProducts =>
      products.where((p) => p.featured).toList();

  List<CatalogProduct> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.tagline.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
  }
}

final catalogDataProvider = FutureProvider<CatalogData>((ref) {
  return CatalogData.load();
});
