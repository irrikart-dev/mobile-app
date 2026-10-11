import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';
import '../core/storage/local_store.dart';
import 'catalog_data.dart';
import 'catalog_product.dart';

/// The signed-in user's server-side catalogue lists: wishlist and recently
/// viewed. All auth-only; both lists come back as full products, newest
/// first, and silently drop products that were later hidden or delisted.
class CatalogUserRepository {
  CatalogUserRepository(this._dio);

  final Dio _dio;

  static List<CatalogProduct> _products(dynamic data) => (data as List)
      .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<List<CatalogProduct>> fetchWishlist() =>
      apiRequest(() => _dio.get<dynamic>('/catalog/wishlist'), _products);

  /// Idempotent. `404` when the product isn't live. Returns the whole
  /// updated wishlist.
  Future<List<CatalogProduct>> addToWishlist(String productId) => apiRequest(
        () => _dio.post<dynamic>('/catalog/wishlist/$productId'),
        _products,
      );

  /// No error if it wasn't there. Returns the whole updated wishlist.
  Future<List<CatalogProduct>> removeFromWishlist(String productId) =>
      apiRequest(
        () => _dio.delete<dynamic>('/catalog/wishlist/$productId'),
        _products,
      );

  /// Last 20, most recent first.
  Future<List<CatalogProduct>> fetchRecentlyViewed() => apiRequest(
        () => _dio.get<dynamic>('/catalog/recently-viewed'),
        _products,
      );

  /// `204`, no body — so not through [apiRequest], which expects one.
  Future<void> recordView(String productId) =>
      _dio.post<dynamic>('/catalog/recently-viewed/$productId');
}

final catalogUserRepositoryProvider = Provider<CatalogUserRepository>(
  (ref) => CatalogUserRepository(ref.watch(dioProvider)),
);

/// Server wishlist (newest first) → the controller's slug set, which keeps
/// insertion order oldest → newest (what the wishlist screen reverses).
@visibleForTesting
Set<String> wishlistSlugsFromServer(List<CatalogProduct> products) =>
    {for (final p in products.reversed) p.slug};

/// Wishlist as a set of product **slugs** — what every heart icon and the
/// wishlist screen read, whoever is signed in.
///
/// - Signed out: persisted on-device, exactly as before.
/// - Signed in: the server (`/catalog/wishlist`) is the source of truth.
///   Slugs map to the product **ids** the API keys off through the loaded
///   catalogue. [toggle] is optimistic and rolls back on failure.
/// - On sign-in, anything saved while signed out is pushed to the server
///   once, then cleared from the device.
class WishlistController extends Notifier<Set<String>> {
  /// Bumped on every rebuild so a server response that lands after a sign
  /// out (or a newer sync) is dropped instead of overwriting fresher state.
  int _generation = 0;

  /// Toggles still in flight: slug → wanted state. Re-applied over any
  /// server list that lands meanwhile, so a sync can't undo a tap.
  final Map<String, bool> _pending = {};

  @override
  Set<String> build() {
    final store = ref.watch(localStoreProvider);
    final generation = ++_generation;
    if (!ref.watch(isSignedInProvider)) return store.wishlist;
    unawaited(_syncFromServer(generation));
    // Until the server list lands, show whatever was saved signed out — it
    // is about to be pushed to the account anyway.
    return store.wishlist;
  }

  bool get _signedIn => ref.read(isSignedInProvider);

  /// Re-reads the server wishlist (pull to refresh). No-op signed out.
  Future<void> refresh() async {
    if (_signedIn) await _syncFromServer(_generation);
  }

  Future<void> _syncFromServer(int generation) async {
    final repo = ref.read(catalogUserRepositoryProvider);
    try {
      await _pushGuestItems(repo);
      final products = await repo.fetchWishlist();
      if (generation != _generation) return;
      _reconcile(products);
    } catch (error) {
      debugPrint('IrriKart: wishlist sync failed ($error)');
    }
  }

  /// Moves the signed-out wishlist onto the account. Items that can't be
  /// mapped to a live id right now (offline catalogue, network error) stay
  /// on the device and are retried on the next sync; products that are no
  /// longer live (`404`) are dropped.
  Future<void> _pushGuestItems(CatalogUserRepository repo) async {
    final store = ref.read(localStoreProvider);
    final guest = store.wishlist;
    if (guest.isEmpty) return;
    CatalogData? data;
    try {
      data = await ref.read(catalogDataProvider.future);
    } catch (_) {}
    final keep = <String>{};
    for (final slug in guest) {
      final id = data?.productIdForSlug(slug);
      if (id == null) {
        keep.add(slug);
        continue;
      }
      try {
        await repo.addToWishlist(id);
      } on ApiException catch (e) {
        if (!e.isNotFound) keep.add(slug);
      }
    }
    await store.setWishlist(keep);
  }

  void _reconcile(List<CatalogProduct> products) {
    final next = wishlistSlugsFromServer(products);
    _pending.forEach((slug, wanted) {
      if (wanted) {
        next.add(slug);
      } else {
        next.remove(slug);
      }
    });
    state = next;
  }

  /// Adds or removes [slug]. Resolves `true` once it stuck, `false` if it
  /// failed and was rolled back (show [errorMessage]). Callers that don't
  /// care can ignore the result.
  Future<bool> toggle(String slug) async {
    final adding = !state.contains(slug);
    state = _with(state, slug, adding);

    if (!_signedIn) {
      unawaited(ref.read(localStoreProvider).setWishlist(state));
      return true;
    }

    final generation = _generation;
    _pending[slug] = adding;
    try {
      final id = await _idFor(slug);
      if (id == null) throw const ApiException(null, errorMessage);
      final repo = ref.read(catalogUserRepositoryProvider);
      final products = adding
          ? await repo.addToWishlist(id)
          : await repo.removeFromWishlist(id);
      if (_pending[slug] == adding) _pending.remove(slug);
      if (generation == _generation) _reconcile(products);
      return true;
    } catch (error) {
      debugPrint('IrriKart: wishlist toggle failed ($error)');
      // Only roll back if nothing newer has touched this slug since.
      if (_pending[slug] == adding) {
        _pending.remove(slug);
        if (generation == _generation) state = _with(state, slug, !adding);
      }
      return false;
    }
  }

  static const errorMessage =
      'Couldn’t update your wishlist. Check your connection and try again.';

  Future<String?> _idFor(String slug) async {
    final CatalogData data = ref.read(catalogDataProvider).valueOrNull ??
        await ref.read(catalogDataProvider.future);
    return data.productIdForSlug(slug);
  }

  static Set<String> _with(Set<String> set, String slug, bool present) =>
      present
          ? {...set.where((s) => s != slug), slug}
          : ({...set}..remove(slug));

  bool contains(String slug) => state.contains(slug);
}

final wishlistControllerProvider =
    NotifierProvider<WishlistController, Set<String>>(
  WishlistController.new,
);

/// Most-recent-first product slugs the user opened on this device, capped
/// at 12. Kept whoever is signed in (it's the offline fallback); when
/// signed in, each view is also recorded server-side so it follows the
/// account — see [serverRecentlyViewedProvider].
class RecentlyViewedController extends Notifier<List<String>> {
  static const _cap = 12;

  @override
  List<String> build() => ref.watch(localStoreProvider).recentlyViewed;

  /// Call when the product page opens. Fire-and-forget: the server call
  /// (signed in only) resolves the product id through the catalogue.
  void record(String slug) {
    _recordLocal(slug);
    if (ref.read(isSignedInProvider)) unawaited(_post(slug: slug));
  }

  /// Same as [record] when the product is already in hand.
  void recordView(CatalogProduct product) {
    _recordLocal(product.slug);
    if (ref.read(isSignedInProvider)) {
      unawaited(_post(slug: product.slug, id: product.id));
    }
  }

  void _recordLocal(String slug) {
    if (state.isNotEmpty && state.first == slug) return;
    final next = [slug, ...state.where((s) => s != slug)].take(_cap).toList();
    state = next;
    unawaited(ref.read(localStoreProvider).setRecentlyViewed(next));
  }

  Future<void> _post({required String slug, String? id}) async {
    try {
      var productId = (id == null || id.isEmpty) ? null : id;
      if (productId == null) {
        final data = await ref.read(catalogDataProvider.future);
        productId = data.productIdForSlug(slug);
      }
      if (productId == null) return; // offline fixtures — nothing to send
      await ref.read(catalogUserRepositoryProvider).recordView(productId);
      ref.invalidate(serverRecentlyViewedProvider);
    } catch (error) {
      debugPrint('IrriKart: recording a product view failed ($error)');
    }
  }
}

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedController, List<String>>(
  RecentlyViewedController.new,
);

/// The signed-in user's recently viewed products from
/// `GET /catalog/recently-viewed` (last 20, newest first). Empty when signed
/// out — use the on-device [recentlyViewedProvider] then.
final serverRecentlyViewedProvider =
    FutureProvider<List<CatalogProduct>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const [];
  return ref.watch(catalogUserRepositoryProvider).fetchRecentlyViewed();
});

/// Most-recent-first search terms, capped at 8.
class RecentSearchesController extends Notifier<List<String>> {
  static const _cap = 8;

  @override
  List<String> build() => ref.watch(localStoreProvider).recentSearches;

  void record(String term) {
    final t = term.trim();
    if (t.length < 2) return;
    final next = [
      t,
      ...state.where((s) => s.toLowerCase() != t.toLowerCase()),
    ].take(_cap).toList();
    state = next;
    ref.read(localStoreProvider).setRecentSearches(next);
  }

  void remove(String term) {
    final next = state.where((s) => s != term).toList();
    state = next;
    ref.read(localStoreProvider).setRecentSearches(next);
  }

  void clear() {
    state = const [];
    ref.read(localStoreProvider).setRecentSearches(const []);
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
  RecentSearchesController.new,
);
