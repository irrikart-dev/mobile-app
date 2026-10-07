import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_store.dart';

/// Wishlist — a set of product slugs, persisted on-device so it survives
/// restarts. There is no wishlist API yet; when one lands this becomes the
/// cache in front of it.
class WishlistController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(localStoreProvider).wishlist;

  void toggle(String slug) {
    final next = {...state};
    if (!next.remove(slug)) next.add(slug);
    state = next;
    ref.read(localStoreProvider).setWishlist(next);
  }

  bool contains(String slug) => state.contains(slug);
}

final wishlistControllerProvider =
    NotifierProvider<WishlistController, Set<String>>(
  WishlistController.new,
);

/// Most-recent-first product slugs the user opened, capped at 12.
class RecentlyViewedController extends Notifier<List<String>> {
  static const _cap = 12;

  @override
  List<String> build() => ref.watch(localStoreProvider).recentlyViewed;

  void record(String slug) {
    if (state.isNotEmpty && state.first == slug) return;
    final next = [slug, ...state.where((s) => s != slug)].take(_cap).toList();
    state = next;
    ref.read(localStoreProvider).setRecentlyViewed(next);
  }
}

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedController, List<String>>(
  RecentlyViewedController.new,
);

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
