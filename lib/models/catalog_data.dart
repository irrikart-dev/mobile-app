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

  /// Builds a catalogue directly — tests and screenshot tooling only.
  @visibleForTesting
  const CatalogData.forTesting({
    required this.categories,
    required this.products,
    this.source = CatalogSource.api,
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

  /// `GET /catalog/brands` — public, sorted by name.
  static Future<List<CatalogBrand>> fetchBrands(Dio dio) {
    return apiRequest(
      () => dio.get<dynamic>('/catalog/brands'),
      (data) => (data as List)
          .map((e) => CatalogBrand.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Brands derived from the loaded products themselves — the fallback when
  /// `GET /catalog/brands` can't be reached. Empty on the bundled fixtures
  /// (they carry no brand), which simply hides the brand filter offline.
  List<CatalogBrand> get derivedBrands {
    final byId = <String, CatalogBrand>{};
    for (final p in products) {
      final id = p.brandId;
      if (id == null || id.isEmpty) continue;
      final seen = byId[id];
      byId[id] = CatalogBrand(
        id: id,
        slug: seen?.slug ?? id,
        name: seen?.name ?? p.brandName ?? 'Other',
        productCount: (seen?.productCount ?? 0) + 1,
      );
    }
    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  /// The live product id for [slug] — what the wishlist and recently-viewed
  /// endpoints key off. Null when the slug isn't in the catalogue, or the
  /// catalogue is the bundled fixtures (which have no ids).
  String? productIdForSlug(String slug) {
    final id = productBySlug(slug)?.id;
    return (id == null || id.isEmpty) ? null : id;
  }

  /// The product that owns [variantId] (any of its variants, not only the
  /// default one), paired with that variant when the product carries its
  /// variant list. Null for an empty id — the bundled fixtures have none.
  ({CatalogProduct product, CatalogVariant? variant})? findVariant(
    String variantId,
  ) {
    if (variantId.isEmpty) return null;
    for (final p in products) {
      for (final v in p.variants) {
        if (v.id == variantId) return (product: p, variant: v);
      }
      if (p.variantId == variantId) return (product: p, variant: null);
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

/// One `GET /catalog/brands` entry.
class CatalogBrand {
  const CatalogBrand({
    required this.id,
    required this.slug,
    required this.name,
    required this.productCount,
  });

  final String id;
  final String slug;
  final String name;
  final int productCount;

  factory CatalogBrand.fromJson(Map<String, dynamic> json) {
    return CatalogBrand(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Product-list sort orders, matching the API's `sort` values one to one.
enum CatalogSort {
  /// The API's own order (most recently edited first) — the catalogue is
  /// loaded in that order, so this leaves the list untouched.
  newest('newest'),
  priceAsc('price_asc'),
  priceDesc('price_desc'),

  /// Review count, highest first — the contract's definition of "popular".
  popular('popular'),
  rating('rating');

  const CatalogSort(this.apiValue);

  /// The `sort` query value for `GET /catalog/products`.
  final String apiValue;
}

/// The product-list filters (`brand`, `minPrice`/`maxPrice`, `minRating`,
/// `inStock`, `sort` in the API) applied locally to the in-memory
/// catalogue, with the semantics the API documents — so a list reads the
/// same whether it came from the API or the offline fixtures.
@immutable
class CatalogFilter {
  const CatalogFilter({
    this.brandIds = const {},
    this.minRating,
    this.inStockOnly = false,
    this.minPrice,
    this.maxPrice,
    this.sort = CatalogSort.newest,
  });

  /// Empty = any brand. Otherwise products of any of these brands.
  final Set<String> brandIds;

  /// Product rating `>=` this, or null for any.
  final double? minRating;

  /// Marked in stock **and** at least one variant with stock on hand.
  final bool inStockOnly;

  /// Any variant priced within `[minPrice, maxPrice]`; null = unbounded.
  final num? minPrice;
  final num? maxPrice;

  final CatalogSort sort;

  bool get hasPrice => minPrice != null || maxPrice != null;

  /// True when anything narrows or reorders the list.
  bool get isActive =>
      brandIds.isNotEmpty ||
      minRating != null ||
      inStockOnly ||
      hasPrice ||
      sort != CatalogSort.newest;

  /// [minRating] and [price] are wrapped so they can be set back to null.
  CatalogFilter copyWith({
    Set<String>? brandIds,
    double? Function()? minRating,
    bool? inStockOnly,
    ({num? min, num? max})? price,
    CatalogSort? sort,
  }) {
    return CatalogFilter(
      brandIds: brandIds ?? this.brandIds,
      minRating: minRating != null ? minRating() : this.minRating,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      minPrice: price != null ? price.min : minPrice,
      maxPrice: price != null ? price.max : maxPrice,
      sort: sort ?? this.sort,
    );
  }

  static bool _hasStock(CatalogProduct p) => p.variants.isEmpty
      ? p.stockQty > 0
      : p.variants.any((v) => v.stockQty > 0);

  /// Every price a product can be bought at — its variant prices, or the
  /// single top-level price when the variant list isn't loaded.
  static Iterable<num> prices(CatalogProduct p) =>
      p.variants.isEmpty ? [p.price] : p.variants.map((v) => v.price);

  bool matches(CatalogProduct p) {
    if (brandIds.isNotEmpty && !brandIds.contains(p.brandId)) return false;
    final rating = minRating;
    if (rating != null && p.rating < rating) return false;
    if (inStockOnly && !(p.inStock && _hasStock(p))) return false;
    if (hasPrice) {
      final lo = minPrice ?? double.negativeInfinity;
      final hi = maxPrice ?? double.infinity;
      if (!prices(p).any((v) => v >= lo && v <= hi)) return false;
    }
    return true;
  }

  /// Filters, then sorts. Ties keep the incoming (API) order.
  List<CatalogProduct> apply(List<CatalogProduct> products) {
    final indexed = [
      for (var i = 0; i < products.length; i++)
        if (matches(products[i])) (i: i, p: products[i]),
    ];
    indexed.sort((a, b) {
      final byKey = switch (sort) {
        CatalogSort.newest => 0,
        CatalogSort.priceAsc => a.p.price.compareTo(b.p.price),
        CatalogSort.priceDesc => b.p.price.compareTo(a.p.price),
        CatalogSort.popular => b.p.reviewCount != a.p.reviewCount
            ? b.p.reviewCount.compareTo(a.p.reviewCount)
            : b.p.rating.compareTo(a.p.rating),
        CatalogSort.rating => b.p.rating != a.p.rating
            ? b.p.rating.compareTo(a.p.rating)
            : b.p.reviewCount.compareTo(a.p.reviewCount),
      };
      return byKey != 0 ? byKey : a.i.compareTo(b.i);
    });
    return [for (final e in indexed) e.p];
  }
}

/// The catalogue. `ref.invalidate(catalogDataProvider)` refetches — that is
/// what pull-to-refresh on the home screen is wired to, and it is how a
/// dashboard edit reaches an app that is already open.
final catalogDataProvider = FutureProvider<CatalogData>((ref) {
  return CatalogData.load(ref.watch(dioProvider));
});

/// Every brand, for the product-list brand filter. Falls back to brands
/// derived from the loaded catalogue when the endpoint can't be reached —
/// an empty list on the bundled fixtures, which hides the filter.
final brandsProvider = FutureProvider<List<CatalogBrand>>((ref) async {
  try {
    return await CatalogData.fetchBrands(ref.watch(dioProvider));
  } catch (error) {
    debugPrint('IrriKart: brands unavailable ($error) — deriving locally.');
    final data = await ref.watch(catalogDataProvider.future);
    return data.derivedBrands;
  }
});

/// A home hero banner from `GET /catalog/banners`, managed in the admin
/// dashboard. [link] is an app route (see `openAppLink`), not a web URL.
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    this.eyebrow = '',
    this.subtitle = '',
    this.ctaLabel = '',
    this.link,
    this.imageUrl,
  });

  final String id;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String? link;
  final String? imageUrl;

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        id: json['id'] as String,
        eyebrow: json['eyebrow'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        ctaLabel: json['ctaLabel'] as String? ?? '',
        link: json['link'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// Active banners in display order. Empty on any failure, which keeps the
/// built-in slides.
final promoBannersProvider = FutureProvider<List<PromoBanner>>((ref) async {
  try {
    return await apiRequest(
      () => ref.watch(dioProvider).get<dynamic>('/catalog/banners'),
      (data) => (data as List)
          .map((e) => PromoBanner.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  } catch (error) {
    debugPrint('IrriKart: banners unavailable ($error) — using built-ins.');
    return const [];
  }
});
