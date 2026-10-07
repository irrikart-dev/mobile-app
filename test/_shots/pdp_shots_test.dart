@Tags(['shots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/models/cart_state.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/order_data.dart';
import 'package:irrikart/models/review_data.dart';
import 'package:irrikart/screens/product/views/product_details_screen.dart';
import 'package:irrikart/screens/product/views/product_returns_screen.dart';
import 'package:irrikart/screens/reviews/view/product_reviews_screen.dart';
import 'package:irrikart/screens/reviews/view/reviews_providers.dart';

import 'harness.dart';

/// Serves assets from disk, with `products.json` patched so one product has
/// variants, a multi-photo gallery and a category name — the richest PDP.
void _mockAssets(WidgetTester t) {
  rootBundle.clear();
  t.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
      (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List()));
    final built = File('build/unit_test_assets/$key');
    final file = built.existsSync() ? built : File(key);
    if (!file.existsSync()) return null;
    if (key == 'assets/mock/products.json') {
      final list = jsonDecode(file.readAsStringSync()) as List;
      for (final p in list.cast<Map<String, dynamic>>()) {
        p['id'] = 'id-${p['slug']}';
        p['categoryName'] = 'Sprinklers';
        if (p['slug'] == 'rps-select') {
          final img = p['image'] as String;
          p['images'] = [img, img, img, img];
          p['variants'] = [
            {
              'id': 'v1',
              'size': '1/2" inlet',
              'unit': 'piece',
              'price': 1619,
              'stockQty': 40,
            },
            {
              'id': 'v2',
              'size': '3/4" inlet',
              'unit': 'piece',
              'price': 1749,
              'stockQty': 12,
            },
            {
              'id': 'v3',
              'size': '1" inlet',
              'unit': 'piece',
              'price': 1990,
              'stockQty': 0,
            },
          ];
        }
      }
      return ByteData.sublistView(utf8.encode(jsonEncode(list)));
    }
    return ByteData.sublistView(file.readAsBytesSync());
  });
}

final _reviews = [
  ProductReview(
    id: 'r1',
    rating: 5,
    comment: 'Covers my whole lawn evenly. Arc adjustment from the top is a '
        'real time saver — no tools needed. Installed six of these.',
    userName: 'Ramesh Patil',
    createdAt: DateTime(2026, 9, 28),
  ),
  ProductReview(
    id: 'r2',
    rating: 4,
    comment: 'Solid build, quiet gear drive. Took a day to dial in the '
        'nozzles for the corners.',
    userName: 'Anita Deshmukh',
    createdAt: DateTime(2026, 9, 14),
  ),
  ProductReview(
    id: 'r3',
    rating: 5,
    comment: 'Works well with low pressure from our borewell.',
    userName: 'Kiran S',
    createdAt: DateTime(2026, 8, 30),
  ),
  ProductReview(
    id: 'r4',
    rating: 3,
    comment: null,
    userName: 'Verified buyer',
    createdAt: DateTime(2026, 8, 2),
  ),
  ProductReview(
    id: 'r5',
    rating: 4,
    comment: 'Good value compared to imported rotors.',
    userName: 'Suresh Kumar Reddy',
    createdAt: DateTime(2026, 7, 19),
  ),
];

final _overrides = [
  catalogDataProvider.overrideWith((ref) => CatalogData.loadBundled()),
  productReviewsProvider.overrideWith((ref, id) async => _reviews),
  cartTotalItemsProvider.overrideWithValue(2),
];

/// Lets real async work (asset reads, image decodes) finish, then pumps.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> Function(WidgetTester) _scrollTo(double offset) => (t) async {
      await _settle(t);
      final scrollable = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      final state = t.state<ScrollableState>(scrollable.first);
      final pos = state.position;
      pos.jumpTo(offset.clamp(0, pos.maxScrollExtent));
      await t.pump();
      await _settle(t);
    };

void main() {
  setUpAll(loadShotFonts);

  for (final dark in [false, true]) {
    testWidgets('pdp top $dark', (t) async {
      _mockAssets(t);
      await shot(
        t,
        'pdp_1_top',
        const ProductDetailsScreen(slug: 'rps-select'),
        dark: dark,
        overrides: _overrides,
        before: _settle,
      );
    });
    for (final (i, y) in [(2, 640.0), (3, 1340.0), (4, 2040.0), (5, 99999.0)]) {
      testWidgets('pdp scroll $i $dark', (t) async {
        _mockAssets(t);
        await shot(
          t,
          'pdp_${i}_scroll',
          const ProductDetailsScreen(slug: 'rps-select'),
          dark: dark,
          overrides: _overrides,
          before: _scrollTo(y),
        );
      });
    }
    testWidgets('pdp simple $dark', (t) async {
      _mockAssets(t);
      await shot(
        t,
        'pdp_6_simple',
        const ProductDetailsScreen(slug: 'hans-mini'),
        dark: dark,
        overrides: _overrides,
        before: _settle,
      );
    });
    testWidgets('reviews $dark', (t) async {
      _mockAssets(t);
      await shot(
        t,
        'reviews',
        const ProductReviewsScreen(
          args: ProductReviewsArgs(productId: 'p', productName: 'RPS Select'),
        ),
        dark: dark,
        overrides: _overrides,
        before: _settle,
      );
    });
    testWidgets('reviews signed in $dark', (t) async {
      _mockAssets(t);
      await shot(
        t,
        'reviews_write',
        const ProductReviewsScreen(
          args: ProductReviewsArgs(productId: 'p', productName: 'RPS Select'),
        ),
        dark: dark,
        overrides: [
          ..._overrides,
          isSignedInProvider.overrideWithValue(true),
          reviewableItemProvider.overrideWith(
            (ref, id) async => const OrderItem(
              id: 'oi1',
              variantId: 'v1',
              productId: 'p',
              name: 'RPS Select',
              slug: 'rps-select',
              image: null,
              sku: 'RPS',
              quantity: 1,
              unitPrice: 1619,
              totalPrice: 1619,
            ),
          ),
        ],
        before: _settle,
      );
    });
    testWidgets('returns $dark', (t) async {
      _mockAssets(t);
      await shot(t, 'returns', const ProductReturnsScreen(), dark: dark);
    });
    testWidgets('returns scrolled $dark', (t) async {
      _mockAssets(t);
      await shot(
        t,
        'returns_2',
        const ProductReturnsScreen(),
        dark: dark,
        before: _scrollTo(99999),
      );
    });
  }
}
