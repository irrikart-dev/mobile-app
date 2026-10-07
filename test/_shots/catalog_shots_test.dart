@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/components/ui/bottom_nav_bar.dart';
import 'package:irrikart/models/catalog_category.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/wishlist_state.dart';
import 'package:irrikart/screens/bookmark/views/bookmark_screen.dart';
import 'package:irrikart/screens/discover/views/discover_screen.dart';
import 'package:irrikart/screens/home/views/components/category_art.dart';
import 'package:irrikart/screens/home/views/home_screen.dart';
import 'package:irrikart/screens/product/views/product_list_screen.dart';
import 'package:irrikart/screens/search/views/search_screen.dart';

import 'harness.dart';

class _Wishlist extends WishlistController {
  _Wishlist(this._initial);
  final Set<String> _initial;
  @override
  Set<String> build() => _initial;
}

class _Recents extends RecentSearchesController {
  @override
  List<String> build() => const ['drip kit', 'sprinkler'];
}

class _Viewed extends RecentlyViewedController {
  @override
  List<String> build() => const ['hans-mini', 'irrituff-sprinkler'];
}

late CatalogData _data;

/// Stand-in for EntryPoint (which compiles every screen in the app): the
/// same extendBody scaffold + floating nav around one tab.
class _Shell extends StatelessWidget {
  const _Shell(this.index, this.child);
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: index,
          onTap: (_) {},
          items: const [
            NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            NavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: 'Categories',
            ),
            NavItem(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag_rounded,
              label: 'Cart',
            ),
            NavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Orders',
            ),
            NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Account',
            ),
          ],
        ),
      );
}

final _catalog = catalogDataProvider.overrideWith((ref) => _data);

/// Decodes every on-screen image for real so goldens show them.
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

Future<void> Function(WidgetTester) _scroll(double dy) => (t) async {
      await _loadImages(t);
      await t.drag(find.byType(CustomScrollView).first, Offset(0, -dy));
      await t.pump(const Duration(milliseconds: 600));
      await _loadImages(t);
    };

void main() {
  setUpAll(() async {
    await loadShotFonts();
    // Bundled fixtures, presented as a live (online) catalogue so shots
    // match what users normally see.
    final bundled = await CatalogData.loadBundled();
    _data = CatalogData.forTesting(
      categories: bundled.categories,
      products: bundled.products,
    );
  });
  for (final dark in [false, true]) {
    // Categories without images (e.g. fresh from the admin dashboard) fall
    // back to their glyph.
    testWidgets(
      'category icons $dark',
      (t) => shot(
        t,
        'cat_icons',
        Scaffold(
          body: GridView.count(
            crossAxisCount: 4,
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final c in [
                ..._data.categories,
                for (final n in [
                  'Drip Irrigation',
                  'Pumps',
                  'Tools',
                  'Fertilizers',
                  'Seeds',
                ])
                  CatalogCategory(
                    id: n,
                    slug: n,
                    name: n,
                    blurb: '',
                    image: null,
                    imageUrl: null,
                    productCount: 0,
                  ),
              ])
                CategoryArt(
                  category: CatalogCategory(
                    id: c.id,
                    slug: c.slug,
                    name: c.name,
                    blurb: '',
                    image: null,
                    imageUrl: null,
                    productCount: 0,
                  ),
                ),
            ],
          ),
        ),
        dark: dark,
      ),
    );
    testWidgets(
      'home $dark',
      (t) => shot(
        t,
        'cat_home',
        const _Shell(0, HomeScreen()),
        dark: dark,
        overrides: [
          _catalog,
          recentlyViewedProvider.overrideWith(_Viewed.new),
        ],
        before: _loadImages,
      ),
    );
    testWidgets(
      'home2 $dark',
      (t) => shot(
        t,
        'cat_home2',
        const _Shell(0, HomeScreen()),
        dark: dark,
        overrides: [
          _catalog,
          recentlyViewedProvider.overrideWith(_Viewed.new),
        ],
        before: _scroll(700),
      ),
    );
    testWidgets(
      'home3 $dark',
      (t) => shot(
        t,
        'cat_home3',
        const _Shell(0, HomeScreen()),
        dark: dark,
        overrides: [
          _catalog,
          recentlyViewedProvider.overrideWith(_Viewed.new),
        ],
        before: _scroll(1350),
      ),
    );
    testWidgets(
      'categories $dark',
      (t) => shot(
        t,
        'cat_categories',
        const _Shell(1, DiscoverScreen()),
        dark: dark,
        overrides: [_catalog],
        before: _loadImages,
      ),
    );
    testWidgets(
      'search idle $dark',
      (t) => shot(
        t,
        'cat_search',
        const SearchScreen(),
        dark: dark,
        overrides: [
          _catalog,
          recentSearchesProvider.overrideWith(_Recents.new),
        ],
        before: _loadImages,
      ),
    );
    testWidgets(
      'search results $dark',
      (t) => shot(
        t,
        'cat_search_results',
        const SearchScreen(),
        dark: dark,
        overrides: [_catalog],
        before: (t) async {
          await t.enterText(find.byType(TextField), 'sprinkler');
          await t.testTextInput.receiveAction(TextInputAction.search);
          await t.pump(const Duration(milliseconds: 600));
          await _loadImages(t);
        },
      ),
    );
    testWidgets(
      'search empty $dark',
      (t) => shot(
        t,
        'cat_search_empty',
        const SearchScreen(),
        dark: dark,
        overrides: [_catalog],
        before: (t) async {
          await t.enterText(find.byType(TextField), 'tractor');
          await t.testTextInput.receiveAction(TextInputAction.search);
          await t.pump(const Duration(milliseconds: 600));
        },
      ),
    );
    testWidgets(
      'product list $dark',
      (t) => shot(
        t,
        'cat_plist',
        const ProductListScreen(categoryId: 'sprinklers'),
        dark: dark,
        overrides: [_catalog],
        before: _loadImages,
      ),
    );
    testWidgets(
      'wishlist $dark',
      (t) => shot(
        t,
        'cat_wishlist',
        const BookmarkScreen(),
        dark: dark,
        overrides: [
          _catalog,
          wishlistControllerProvider.overrideWith(
            () => _Wishlist({
              'hans-mini',
              'irrituff-sprinkler',
              'arrow-dripper-assembly',
            }),
          ),
        ],
        before: _loadImages,
      ),
    );
    testWidgets(
      'wishlist empty $dark',
      (t) => shot(
        t,
        'cat_wishlist_empty',
        const BookmarkScreen(),
        dark: dark,
        overrides: [_catalog],
      ),
    );
  }
}
