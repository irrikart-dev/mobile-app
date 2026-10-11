@Tags(['shots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/components/ui/ui.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/entry_point_tab.dart';
import 'package:irrikart/models/cart_state.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/catalog_product.dart';
import 'package:irrikart/screens/checkout/views/cart_screen.dart';
import 'package:irrikart/screens/product/views/product_list_screen.dart';

import 'harness.dart';

/// Bundled fixtures with brands stamped on (the fixtures predate brands),
/// so the brand filter has something to show.
late CatalogData _data;

const _brands = {
  'arrow-dripper-assembly': ('b-jain', 'Jain Irrigation'),
  'hans-mini': ('b-finolex', 'Finolex'),
  'mini-mikro-sprinkler': ('b-jain', 'Jain Irrigation'),
  'irrituff-sprinkler': ('b-netafim', 'Netafim'),
  'irrijet-micro-sprinkler': ('b-netafim', 'Netafim'),
  'hans-plastic': ('b-finolex', 'Finolex'),
  'winkler': ('b-rainbird', 'Rain Bird'),
};

const _img = 'assets/mock/products';

CartLine _line(
  int i,
  String name,
  String image,
  num price,
  int qty, {
  bool guest = false,
}) =>
    CartLine(
      id: guest ? 'guest:v$i' : 'l$i',
      variantId: 'v$i',
      productId: 'p$i',
      name: name,
      slug: 's$i',
      image: '$_img/$image',
      sku: 'SKU$i',
      unit: 'piece',
      quantity: qty,
      price: price,
      lineTotal: price * qty,
      available: 20,
    );

Cart _cart({bool guest = false}) {
  final items = [
    _line(
      0,
      'Hans™ Plastic Sprinkler',
      'img003-1-1-600x600.jpg',
      249,
      4,
      guest: guest,
    ),
    _line(
      1,
      'RPS Select Rain Pipe Sprinkler System',
      'img018-rps-select-pr.jpg',
      1899,
      1,
      guest: guest,
    ),
  ];
  final total = items.fold<num>(0, (s, l) => s + l.lineTotal);
  return Cart(
    id: guest ? null : 'c1',
    status: 'ACTIVE',
    items: items,
    itemCount: items.fold<int>(0, (s, l) => s + l.quantity),
    subtotal: total,
    total: total,
  );
}

class _FakeCart extends CartController {
  _FakeCart(this.cart);
  final Cart cart;
  @override
  Future<Cart> build() async => cart;
}

const _skipped = [
  CartMergeSkip(
    variantId: 'v8',
    quantity: 2,
    reason: 'Only 1 of this item available',
    name: 'Winkler Impact Sprinkler',
    image: '$_img/img009-Untitled-design-2-600x600.jpg',
  ),
  CartMergeSkip(
    variantId: 'v9',
    quantity: 1,
    reason: 'Your cart already has items from Kisan Agro. '
        'Check out or clear it before adding items from another seller.',
    name: 'Arrow Dripper Assembly',
    image: '$_img/img012-WEB-P-2-600x600.webp',
  ),
];

Future<void> _loadImages(WidgetTester t) async {
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final img = e.widget as Image;
      try {
        await precacheImage(img.image, e);
      } catch (_) {}
    }
  });
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> Function(WidgetTester) _openChip(String label) => (t) async {
      await _loadImages(t);
      // Scroll the chip row (not the page) until the chip is on screen.
      final row = find.byType(ChipRow);
      for (var i = 0;
          i < 4 && t.getCenter(find.text(label).first).dx > 330;
          i++) {
        await t.drag(row, const Offset(-120, 0));
        await t.pump(const Duration(milliseconds: 300));
      }
      await t.tap(find.text(label).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await _loadImages(t);
    };

void main() {
  setUpAll(() async {
    await loadShotFonts();
    final bundled = await CatalogData.loadBundled();
    final raw = (jsonDecode(
      File('assets/mock/products.json').readAsStringSync(),
    ) as List)
        .cast<Map<String, dynamic>>();
    _data = CatalogData.forTesting(
      categories: bundled.categories,
      products: [
        for (final json in raw)
          CatalogProduct.fromJson({
            ...json,
            if (_brands[json['slug']] case (final id, final name)) ...{
              'brandId': id,
              'brandName': name,
            },
          }),
      ],
    );
  });

  final catalog = catalogDataProvider.overrideWith((ref) => _data);
  final brands = brandsProvider.overrideWith((ref) => _data.derivedBrands);

  for (final dark in [false, true]) {
    for (final (name, chip) in [
      ('plist_filters', null),
      ('plist_sort', 'Sort'),
      ('plist_brand', 'Brand'),
      ('plist_rating', 'Rating'),
    ]) {
      testWidgets(
        '$name $dark',
        (t) => shot(
          t,
          name,
          const ProductListScreen(categoryId: 'sprinklers'),
          dark: dark,
          overrides: [catalog, brands],
          before: chip == null ? _loadImages : _openChip(chip),
        ),
      );
    }

    testWidgets(
      'plist brand applied $dark',
      (t) => shot(
        t,
        'plist_brand_applied',
        const ProductListScreen(categoryId: 'sprinklers'),
        dark: dark,
        overrides: [catalog, brands],
        before: (t) async {
          await _openChip('Brand')(t);
          await t.tap(find.text('Netafim'));
          await t.tap(find.text('Jain Irrigation'));
          await t.pump();
          await t.tap(find.text('Apply'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
          await _openChip('Rating')(t);
          await t.tap(find.text('4 stars & up'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
          await t.drag(find.byType(ChipRow), const Offset(600, 0));
          await t.pump(const Duration(milliseconds: 600));
          await _loadImages(t);
        },
      ),
    );

    testWidgets(
      'cart merge skipped $dark',
      (t) => shot(
        t,
        'cart_merge_skipped',
        const CartScreen(),
        dark: dark,
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          catalog,
          cartControllerProvider.overrideWith(() => _FakeCart(_cart())),
          cartMergeSkippedProvider.overrideWith((ref) => _skipped),
          entryTabIndexProvider.overrideWith((ref) => 2),
        ],
        before: (t) async {
          await t.pump(const Duration(milliseconds: 600));
          await _loadImages(t);
        },
      ),
    );

    testWidgets(
      'cart guest $dark',
      (t) => shot(
        t,
        'cart_guest',
        const CartScreen(),
        dark: dark,
        overrides: [
          catalog,
          cartControllerProvider.overrideWith(
            () => _FakeCart(_cart(guest: true)),
          ),
        ],
        before: _loadImages,
      ),
    );
  }
}
