import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import 'catalog_category.dart';
import 'catalog_product.dart';

/// Where a loaded catalogue came from. Surfaced in the UI as an offline hint.
enum CatalogSource {
  /// Live from the API — includes everything added in the admin dashboard.
  api,

  /// The API was unreachable, so the bundled fixtures were used. Products
  /// added in the dashboard are missing until the next successful load.
  bundledFallback,
}

/// The product catalogue.
///
/// Loads from `GET /api/v1/catalog`, which returns the products carried over
/// from the IrriKart site *and* anything added in the admin dashboard in one
/// list — so a new product or a price change reaches the app with no release.
///
/// If the API cannot be reached the bundled `assets/mock/` fixtures are used
/// instead, which keeps the app usable on a dead connection at the cost of
/// missing whatever was added in the dashboard since the last app build.
///
/// Every screen should read catalogue data through the providers below, not by
/// reaching into this class directly.
class CatalogData {
  const CatalogData._({
    required this.categories,
    required this.products,
    required this.source,
  });

  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;
  final CatalogSource source;

  bool get isOffline => source == CatalogSource.bundledFallback;

  static Future<CatalogData> load(Dio dio) async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/catalog');
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const FormatException('Malformed /catalog response');
      }

      final catalog = CatalogData._(
        categories: (data['categories'] as List)
            .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        products: (data['products'] as List)
            .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: CatalogSource.api,
      );
      // An empty catalogue is more likely a misconfigured backend than a real
      // empty store — the bundled fixtures are the better answer either way.
      if (catalog.products.isNotEmpty) return catalog;
    } catch (error) {
      debugPrint(
        'IrriKart: catalogue API unavailable ($error) — using bundled fixtures.',
      );
    }
    return loadBundled();
  }

  /// Reads the fixtures shipped inside the app bundle.
  static Future<CatalogData> loadBundled() async {
    final categoriesJson =
        await rootBundle.loadString('assets/mock/categories.json');
    final productsJson =
        await rootBundle.loadString('assets/mock/products.json');

    return CatalogData._(
      categories: (jsonDecode(categoriesJson) as List)
          .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (jsonDecode(productsJson) as List)
          .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      source: CatalogSource.bundledFallback,
    );
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
              p.sku.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
  }
}

/// The catalogue. `ref.invalidate(catalogDataProvider)` refetches — that is what
/// pull-to-refresh on the home screen is wired to, and it is how a dashboard
/// edit reaches an app that is already open.
final catalogDataProvider = FutureProvider<CatalogData>((ref) {
  return CatalogData.load(ref.watch(dioProvider));
});
