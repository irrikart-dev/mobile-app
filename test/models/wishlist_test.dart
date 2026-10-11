import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/network/api_envelope.dart';
import 'package:irrikart/core/storage/local_store.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/catalog_product.dart';
import 'package:irrikart/models/wishlist_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fixtures.dart';

final _a = product('drip-kit', id: 'id-a');
final _b = product('pump', id: 'id-b');
final _c = product('valve', id: 'id-c');
final _byId = {
  for (final p in [_a, _b, _c]) p.id: p,
};

class _FakeRepo extends CatalogUserRepository {
  _FakeRepo() : super(Dio());

  /// Server wishlist, newest first.
  List<String> ids = [];
  final calls = <String>[];
  bool fail = false;
  final viewed = <String>[];

  List<CatalogProduct> get _list => [for (final id in ids) _byId[id]!];

  @override
  Future<List<CatalogProduct>> fetchWishlist() async => _list;

  @override
  Future<List<CatalogProduct>> addToWishlist(String productId) async {
    calls.add('+$productId');
    if (fail) throw const ApiException(500, 'down');
    ids = [productId, ...ids.where((i) => i != productId)];
    return _list;
  }

  @override
  Future<List<CatalogProduct>> removeFromWishlist(String productId) async {
    calls.add('-$productId');
    if (fail) throw const ApiException(500, 'down');
    ids = ids.where((i) => i != productId).toList();
    return _list;
  }

  @override
  Future<List<CatalogProduct>> fetchRecentlyViewed() async =>
      [for (final id in viewed) _byId[id]!];

  @override
  Future<void> recordView(String productId) async {
    viewed.remove(productId);
    viewed.insert(0, productId);
  }
}

final _signedIn = StateProvider<bool>((ref) => false);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeRepo repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isSignedInProvider.overrideWith((ref) => ref.watch(_signedIn)),
        catalogDataProvider.overrideWith((ref) async => catalog([_a, _b, _c])),
        catalogUserRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.listen(wishlistControllerProvider, (_, __) {});
    await container.read(catalogDataProvider.future);
  });

  WishlistController wishlist() =>
      container.read(wishlistControllerProvider.notifier);
  Set<String> state() => container.read(wishlistControllerProvider);

  test('slug ↔ id mapping through the catalogue', () {
    final data = catalog([_a, _b]);
    expect(data.productIdForSlug('pump'), 'id-b');
    expect(data.productIdForSlug('missing'), isNull);
    // Bundled fixtures carry no id.
    final fixture = CatalogProduct.fromJson(
      {'slug': 'old', 'name': 'Old', 'category': 'x'},
    );
    expect(catalog([fixture]).productIdForSlug('old'), isNull);
    // Server list (newest first) → slug set (oldest → newest).
    expect(wishlistSlugsFromServer([_b, _a]).toList(), ['drip-kit', 'pump']);
  });

  test('signed out: local slugs only, no server calls', () async {
    expect(await wishlist().toggle('pump'), isTrue);
    expect(state(), {'pump'});
    expect(LocalStore(prefs).wishlist, {'pump'});
    expect(repo.calls, isEmpty);
  });

  test('signed in: toggles post the product id; state follows the server',
      () async {
    repo.ids = ['id-c'];
    container.read(_signedIn.notifier).state = true;
    container.read(wishlistControllerProvider);
    await _settle();
    expect(state(), {'valve'});

    expect(await wishlist().toggle('pump'), isTrue);
    expect(repo.calls, ['+id-b']);
    expect(state().toList(), ['valve', 'pump'], reason: 'newest last');

    expect(await wishlist().toggle('valve'), isTrue);
    expect(repo.calls.last, '-id-c');
    expect(state(), {'pump'});
    expect(LocalStore(prefs).wishlist, isEmpty, reason: 'server is the source');
  });

  test('signed in: failure rolls the optimistic toggle back', () async {
    container.read(_signedIn.notifier).state = true;
    container.read(wishlistControllerProvider);
    await _settle();
    repo.fail = true;

    final pending = wishlist().toggle('pump');
    expect(state(), contains('pump'), reason: 'optimistic');
    expect(await pending, isFalse);
    expect(state(), isNot(contains('pump')));
  });

  test('sign-in pushes the guest wishlist once, then clears it', () async {
    await wishlist().toggle('pump');
    await wishlist().toggle('drip-kit');
    await wishlist().toggle('not-in-catalogue');
    repo.ids = ['id-c'];

    container.read(_signedIn.notifier).state = true;
    container.read(wishlistControllerProvider);
    await _settle();
    await _settle();

    expect(repo.calls, ['+id-b', '+id-a']);
    expect(state(), {'valve', 'pump', 'drip-kit'});
    // Unmappable slugs stay on the device for a later retry.
    expect(LocalStore(prefs).wishlist, {'not-in-catalogue'});
  });

  test('recently viewed: signed in posts the id; signed out stays local',
      () async {
    container.listen(recentlyViewedProvider, (_, __) {});
    final viewed = container.read(recentlyViewedProvider.notifier);

    viewed.record('pump');
    await _settle();
    expect(repo.viewed, isEmpty);
    expect(container.read(recentlyViewedProvider), ['pump']);

    container.read(_signedIn.notifier).state = true;
    viewed.record('valve');
    await _settle();
    viewed.recordView(_a);
    await _settle();
    expect(repo.viewed, ['id-a', 'id-c']);
    expect(
      [
        for (final p
            in await container.read(serverRecentlyViewedProvider.future))
          p.slug,
      ],
      ['drip-kit', 'valve'],
    );
    expect(
      container.read(recentlyViewedProvider),
      ['drip-kit', 'valve', 'pump'],
    );
  });
}
