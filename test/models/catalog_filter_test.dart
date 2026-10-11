import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/catalog_product.dart';

import '_fixtures.dart';

List<String> slugs(List<CatalogProduct> ps) => [for (final p in ps) p.slug];

void main() {
  // API order (most recently edited first) is the list order.
  final a = product(
    'a',
    price: 500,
    rating: 4.6,
    reviewCount: 3,
    brandId: 'b1',
    brandName: 'Jain',
  );
  final b = product(
    'b',
    price: 150,
    rating: 3.4,
    reviewCount: 40,
    brandId: 'b2',
    brandName: 'Finolex',
  );
  final c = product('c', price: 900, rating: 4.6, reviewCount: 12);
  final d = product(
    'd',
    price: 300,
    rating: 2.9,
    reviewCount: 40,
    inStock: false,
    brandId: 'b1',
    brandName: 'Jain',
  );
  // Default variant at 1200 but a second pack size at 250.
  final e = product(
    'e',
    price: 1200,
    rating: 4.0,
    reviewCount: 0,
    stock: 0,
    variants: [
      {'id': 'e1', 'price': 1200, 'stockQty': 0},
      {'id': 'e2', 'price': 250, 'stockQty': 5},
    ],
  );
  final all = [a, b, c, d, e];

  group('CatalogFilter sort', () {
    test('newest keeps the API order', () {
      expect(
        slugs(const CatalogFilter().apply(all)),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });

    test('price ascending / descending use the default variant price', () {
      expect(
        slugs(const CatalogFilter(sort: CatalogSort.priceAsc).apply(all)),
        ['b', 'd', 'a', 'c', 'e'],
      );
      expect(
        slugs(const CatalogFilter(sort: CatalogSort.priceDesc).apply(all)),
        ['e', 'c', 'a', 'd', 'b'],
      );
    });

    test('popular ranks by review count, then rating, then API order', () {
      expect(
        slugs(const CatalogFilter(sort: CatalogSort.popular).apply(all)),
        ['b', 'd', 'c', 'a', 'e'],
      );
    });

    test('top rated ranks by rating, ties by review count', () {
      expect(
        slugs(const CatalogFilter(sort: CatalogSort.rating).apply(all)),
        ['c', 'a', 'e', 'b', 'd'],
      );
    });

    test('sort values match the API', () {
      expect(
        CatalogSort.values.map((s) => s.apiValue),
        ['newest', 'price_asc', 'price_desc', 'popular', 'rating'],
      );
    });
  });

  group('CatalogFilter filters', () {
    test('brand is a multi-select over brandId', () {
      expect(
        slugs(const CatalogFilter(brandIds: {'b1'}).apply(all)),
        ['a', 'd'],
      );
      expect(
        slugs(const CatalogFilter(brandIds: {'b1', 'b2'}).apply(all)),
        ['a', 'b', 'd'],
      );
    });

    test('min rating is inclusive', () {
      expect(
        slugs(const CatalogFilter(minRating: 4).apply(all)),
        ['a', 'c', 'e'],
      );
      expect(
        slugs(const CatalogFilter(minRating: 3).apply(all)),
        ['a', 'b', 'c', 'e'],
      );
    });

    test('in stock = switch on and any variant with stock', () {
      // d: switch off. e: default variant empty but e2 has stock.
      expect(
        slugs(const CatalogFilter(inStockOnly: true).apply(all)),
        ['a', 'b', 'c', 'e'],
      );
    });

    test('price matches any variant in range', () {
      expect(
        slugs(const CatalogFilter(minPrice: 200, maxPrice: 400).apply(all)),
        ['d', 'e'],
      );
      expect(slugs(const CatalogFilter(maxPrice: 150).apply(all)), ['b']);
    });

    test('filters combine with AND and then sort', () {
      const f = CatalogFilter(
        brandIds: {'b1', 'b2'},
        minRating: 3,
        inStockOnly: true,
        sort: CatalogSort.priceAsc,
      );
      expect(slugs(f.apply(all)), ['b', 'a']);
      expect(f.isActive, isTrue);
      expect(const CatalogFilter().isActive, isFalse);
    });

    test('copyWith can clear nullable fields', () {
      const f = CatalogFilter(minRating: 4, minPrice: 1, maxPrice: 2);
      final cleared =
          f.copyWith(minRating: () => null, price: (min: null, max: null));
      expect(cleared.minRating, isNull);
      expect(cleared.hasPrice, isFalse);
    });
  });

  group('brands', () {
    test('derived from products when the endpoint is unavailable', () {
      final brands = catalog(all).derivedBrands;
      expect([for (final b in brands) b.name], ['Finolex', 'Jain']);
      expect(brands.last.productCount, 2);
    });

    test('CatalogBrand parses the API shape', () {
      final b = CatalogBrand.fromJson(
        {'id': 'b1', 'slug': 'jain', 'name': 'Jain', 'productCount': 7},
      );
      expect((b.id, b.slug, b.name, b.productCount), ('b1', 'jain', 'Jain', 7));
    });

    test('product brand fields are nullable', () {
      expect(a.brandId, 'b1');
      expect(a.brandName, 'Jain');
      expect(c.brandId, isNull);
      expect(c.brandName, isNull);
    });
  });
}
