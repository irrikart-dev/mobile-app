import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory wishlist — a set of product slugs. Interim stand-in for
/// `features/wishlist`, same rationale as [CartController].
class WishlistController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String slug) {
    final next = {...state};
    if (!next.remove(slug)) next.add(slug);
    state = next;
  }

  bool contains(String slug) => state.contains(slug);
}

final wishlistControllerProvider =
    NotifierProvider<WishlistController, Set<String>>(
  WishlistController.new,
);
