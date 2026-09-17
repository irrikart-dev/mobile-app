import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';
import 'catalog_category.dart';
import 'catalog_product.dart';

/// Max page size the catalogue contract allows — used to pull the whole
/// product list in as few round trips as possible.
const _pageLimit = 100;

/// Where a loaded catalogue came from. Surfaced in the UI as an offline hint.
enum CatalogSource {
  /// Live from the API.
  api,

  /// The API was unreachable, so the bundled fixtures were used.
  bundledFallback,
}

/// The product catalogue.
///
/// Loads from `GET /api/v1/catalog/categories` and `GET
/// /api/v1/catalog/products` (paginated, pulled to completion here so the
/// rest of the app can keep working off one in-memory list rather than every
/// screen managing its own pagination).
///
/// If the API cannot be reached the bundled `assets/mock/` fixtures are used
/// instead, which keeps the app usable on a dead connection.
///
/// Every screen should read catalogue data through the providers below, not
/// by reaching into this class directly. Per the contract's freshness rules:
/// this has no long-lived cache of its own (`catalogDataProvider` is
/// re-fetched by pull-to-refresh and app-foreground, see `main.dart`), and
/// [fetchFreshProduct] re-reads a single product live right before it is
/// added to the cart, since price and stock are what moves most.
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
      final categories = await _fetchCategories(dio);
      final products = await _fetchAllProducts(dio);
      // An empty catalogue is more likely a misconfigured backend than a
      // real empty store — the bundled fixtures are the better answer either way.
      if (products.isNotEmpty) {
        return CatalogData._(
          categories: categories,
          products: products,
          source: CatalogSource.api,
        );
      }
    } catch (error) {
      debugPrint(
        'IrriKart: catalogue API unavailable ($error) — using bundled fixtures.',
      );
    }
    return loadBundled();
  }

  static Future<List<CatalogCategory>> _fetchCategories(Dio dio) {
    return apiRequest(
      () => dio.get<dynamic>('/catalog/categories'),
      (data) => (data as List)
          .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Walks every page of `GET /catalog/products` at the max page size and
  /// concatenates them — the app still works off one in-memory list rather
  /// than per-screen pagination, so this is the one place that cost is paid.
  static Future<List<CatalogProduct>> _fetchAllProducts(Dio dio) async {
    final all = <CatalogProduct>[];
    var page = 1;
    while (true) {
      final result = await apiRequest(
        () => dio.get<dynamic>(
          '/catalog/products',
          queryParameters: {'page': page, 'limit': _pageLimit},
        ),
        (data) {
          final map = data as Map<String, dynamic>;
          final items = (map['items'] as List)
              .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
              .toList();
          return (items: items, total: (map['total'] as num).toInt());
        },
      );
      all.addAll(result.items);
      if (result.items.length < _pageLimit || all.length >= result.total) break;
      page += 1;
    }
    return all;
  }

  /// Re-reads one product live — call this immediately before adding it to
  /// the cart, per the catalogue contract's "re-fetch before checkout" rule.
  /// Throws [ApiException] (`isNotFound` when the product is gone or was
  /// unpublished) rather than falling back to bundled data — a stale price
  /// or stock count reaching checkout is exactly what this call prevents.
  static Future<CatalogProduct> fetchFreshProduct(Dio dio, String idOrSlug) {
    return apiRequest(
      () => dio.get<dynamic>('/catalog/products/$idOrSlug'),
      (data) => CatalogProduct.fromJson(data as Map<String, dynamic>),
    );
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

/// The catalogue. `ref.invalidate(catalogDataProvider)` refetches — that is
/// what pull-to-refresh on the home screen is wired to, and it is how a
/// dashboard edit reaches an app that is already open.
final catalogDataProvider = FutureProvider<CatalogData>((ref) {
  return CatalogData.load(ref.watch(dioProvider));
});
