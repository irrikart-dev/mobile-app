import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_product.dart';

class CartLine {
  const CartLine({required this.product, required this.qty});

  final CatalogProduct product;
  final int qty;

  int get lineTotal => product.price * qty;

  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty);
}

/// In-memory cart state.
///
/// Interim stand-in for `features/cart` — no guest/logged-in merge, no
/// persistence, no stock re-check. Good enough to make the Cart and Checkout
/// screens real for this design pass; the full cart feature replaces it.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  void add(CatalogProduct product, {int qty = 1}) {
    final i = state.indexWhere((l) => l.product.slug == product.slug);
    if (i == -1) {
      state = [...state, CartLine(product: product, qty: qty)];
    } else {
      final updated = [...state];
      updated[i] = updated[i].copyWith(qty: updated[i].qty + qty);
      state = updated;
    }
  }

  void setQty(String slug, int qty) {
    if (qty <= 0) {
      remove(slug);
      return;
    }
    state = [
      for (final line in state)
        if (line.product.slug == slug) line.copyWith(qty: qty) else line,
    ];
  }

  void remove(String slug) {
    state = state.where((l) => l.product.slug != slug).toList();
  }

  void clear() => state = const [];

  int get totalItems => state.fold(0, (sum, l) => sum + l.qty);

  int get subtotal => state.fold(0, (sum, l) => sum + l.lineTotal);

  int get mrpTotal => state.fold(0, (sum, l) => sum + l.product.mrp * l.qty);

  int get savings => mrpTotal - subtotal;

  static const int freeDeliveryThreshold = 999;
  static const int deliveryFee = 49;

  int get deliveryFee_ =>
      subtotal >= freeDeliveryThreshold || state.isEmpty ? 0 : deliveryFee;

  int get grandTotal => subtotal + deliveryFee_;
}

final cartControllerProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);

final cartTotalItemsProvider = Provider<int>((ref) {
  final lines = ref.watch(cartControllerProvider);
  return lines.fold(0, (sum, l) => sum + l.qty);
});
