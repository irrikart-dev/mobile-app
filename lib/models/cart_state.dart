import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

export '../core/network/api_envelope.dart' show AuthRequiredException;

/// A message safe to show a user for any error a cart call can throw.
String cartErrorMessage(Object error) {
  if (error is AuthRequiredException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (error is ApiException) {
    if (error.isConflict) return error.message; // names how many are available
    if (error.isNotFound) return 'That item is no longer in your cart.';
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

/// One line in the cart, exactly as `GET /cart` / every cart mutation
/// returns it.
class CartLine {
  const CartLine({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.name,
    required this.slug,
    required this.image,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.lineTotal,
    required this.available,
  });

  /// This line's id — use it for `PATCH`/`DELETE`, **not** [variantId].
  final String id;

  final String variantId;

  /// For linking back to the product detail screen.
  final String productId;

  final String name;
  final String slug;

  /// Absolute URL, same convention as the catalogue's `imageUrl`. `null`
  /// means render a placeholder.
  final String? image;

  final String sku;
  final String unit;
  final int quantity;

  /// Price **at the time this line was last touched** (add or quantity
  /// update) — not necessarily the current live price. Re-fetch the cart
  /// immediately before checkout so totals are current.
  final num price;

  final num lineTotal;

  /// `stock - reserved` on the variant right now. Can be lower than
  /// [quantity] if stock moved after this line was added — surface that,
  /// don't silently clamp the quantity.
  final int available;

  bool get hasRemoteImage => image != null && image!.isNotEmpty;

  factory CartLine.fromJson(Map<String, dynamic> json) {
    return CartLine(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      productId: json['productId'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      image: json['image'] as String?,
      sku: json['sku'] as String? ?? '',
      unit: json['unit'] as String? ?? 'piece',
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num?) ?? 0,
      lineTotal: (json['lineTotal'] as num?) ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The caller's cart, exactly as `GET /cart` returns it.
class Cart {
  const Cart({
    required this.id,
    required this.status,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.total,
  });

  /// A brand-new account's cart, before anything has ever been added.
  static const empty = Cart(
    id: null,
    status: 'ACTIVE',
    items: [],
    itemCount: 0,
    subtotal: 0,
    total: 0,
  );

  final String? id;
  final String status;
  final List<CartLine> items;
  final int itemCount;
  final num subtotal;

  /// Currently always equal to [subtotal] — no tax/shipping/discount line
  /// yet. Both exist so a future addition doesn't change the response shape.
  final num total;

  bool get isEmpty => items.isEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      items: ((json['items'] as List?) ?? const [])
          .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?) ?? 0,
      total: (json['total'] as num?) ?? 0,
    );
  }
}

/// Every cart endpoint is user-scoped and auth-only — there is no
/// guest/anonymous cart, and nothing to merge on login/logout. The Dio
/// interceptor in `api_client.dart` attaches the Firebase ID token; this
/// repository only has to unwrap the envelope and translate a persistent
/// `401` into [AuthRequiredException].
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  Future<Cart> fetch() => _call(() => _dio.get<dynamic>('/cart'));

  /// If [variantId] is already in the cart this **adds to** the existing
  /// quantity — it does not duplicate the line or reset it.
  Future<Cart> addItem(String variantId, {int quantity = 1}) => _call(
        () => _dio.post<dynamic>(
          '/cart/items',
          data: {'variantId': variantId, 'quantity': quantity},
        ),
      );

  /// [quantity] must be `>= 1` — the backend rejects `0` as a way to remove
  /// a line; call [removeItem] for that instead.
  Future<Cart> updateQuantity(String itemId, int quantity) => _call(
        () => _dio.patch<dynamic>(
          '/cart/items/$itemId',
          data: {'quantity': quantity},
        ),
      );

  Future<Cart> removeItem(String itemId) =>
      _call(() => _dio.delete<dynamic>('/cart/items/$itemId'));

  Future<Cart> clear() => _call(() => _dio.delete<dynamic>('/cart'));

  Future<Cart> _call(Future<Response<dynamic>> Function() request) async {
    try {
      return await apiRequest(
        request,
        (data) => Cart.fromJson(data as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) throw const AuthRequiredException();
      rethrow;
    }
  }
}

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(dioProvider)),
);

/// The signed-in user's cart. Rebuilds automatically when sign-in state
/// changes — there is nothing to migrate, the cart is always whoever is
/// currently signed in.
class CartController extends AsyncNotifier<Cart> {
  // Line ids with a remove/quantity request currently in flight — guards
  // against a rapid double-tap firing two overlapping requests for the same
  // line (the optimistic update below makes a second tap feel free, so
  // without this a fast double-tap could race two PATCH/DELETE calls).
  final Set<String> _pendingLineIds = {};

  @override
  Future<Cart> build() async {
    if (!ref.watch(isSignedInProvider)) return Cart.empty;
    return ref.read(cartRepositoryProvider).fetch();
  }

  /// Re-fetches from the server, bypassing whatever is currently held —
  /// always do this immediately before checkout (see the cart contract's
  /// "re-fetch before checkout" rule).
  Future<void> refresh() async {
    if (!ref.read(isSignedInProvider)) {
      state = const AsyncData(Cart.empty);
      return;
    }
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => ref.read(cartRepositoryProvider).fetch());
  }

  Future<void> add(String variantId, {int quantity = 1}) async {
    final cart = await ref
        .read(cartRepositoryProvider)
        .addItem(variantId, quantity: quantity);
    state = AsyncData(cart);
  }

  /// `quantity` must be `>= 1` — call [remove] to drop a line to zero.
  ///
  /// Updates [state] optimistically — the line's quantity/total (and the
  /// cart's subtotal/total) change the instant this is called, before the
  /// network round-trip, so the UI never sits inert waiting on a PATCH. On
  /// failure the optimistic change is rolled back and the error rethrown,
  /// same as it would be from a plain awaited call.
  Future<void> setQuantity(String itemId, int quantity) async {
    if (!_pendingLineIds.add(itemId)) return;
    final previous = state;
    final current = previous.valueOrNull;
    if (current != null) {
      state = AsyncData(_withUpdatedQuantity(current, itemId, quantity));
    }
    try {
      final cart =
          await ref.read(cartRepositoryProvider).updateQuantity(itemId, quantity);
      state = AsyncData(cart);
    } catch (_) {
      state = previous;
      rethrow;
    } finally {
      _pendingLineIds.remove(itemId);
    }
  }

  /// Same optimistic-then-reconcile pattern as [setQuantity] — the line
  /// disappears from [state] immediately, not after the DELETE resolves.
  Future<void> remove(String itemId) async {
    if (!_pendingLineIds.add(itemId)) return;
    final previous = state;
    final current = previous.valueOrNull;
    if (current != null) {
      state = AsyncData(_withoutLine(current, itemId));
    }
    try {
      final cart = await ref.read(cartRepositoryProvider).removeItem(itemId);
      state = AsyncData(cart);
    } catch (_) {
      state = previous;
      rethrow;
    } finally {
      _pendingLineIds.remove(itemId);
    }
  }

  Future<void> clear() async {
    final cart = await ref.read(cartRepositoryProvider).clear();
    state = AsyncData(cart);
  }
}

/// Recomputes `itemCount`/`subtotal`/`total` from a line list — the same
/// arithmetic the server does, used only to make an optimistic update look
/// right for the moment before the server's authoritative cart lands.
Cart _withLines(Cart cart, List<CartLine> items) {
  final subtotal = items.fold<num>(0, (sum, l) => sum + l.lineTotal);
  return Cart(
    id: cart.id,
    status: cart.status,
    items: items,
    itemCount: items.fold<int>(0, (sum, l) => sum + l.quantity),
    subtotal: subtotal,
    total: subtotal,
  );
}

Cart _withUpdatedQuantity(Cart cart, String itemId, int quantity) {
  final items = [
    for (final line in cart.items)
      if (line.id == itemId)
        CartLine(
          id: line.id,
          variantId: line.variantId,
          productId: line.productId,
          name: line.name,
          slug: line.slug,
          image: line.image,
          sku: line.sku,
          unit: line.unit,
          quantity: quantity,
          price: line.price,
          lineTotal: line.price * quantity,
          available: line.available,
        )
      else
        line,
  ];
  return _withLines(cart, items);
}

Cart _withoutLine(Cart cart, String itemId) {
  final items = cart.items.where((l) => l.id != itemId).toList();
  return _withLines(cart, items);
}

final cartControllerProvider = AsyncNotifierProvider<CartController, Cart>(
  CartController.new,
);

/// Cart tab badge. `0` while the cart is loading or on an unauthenticated
/// device, same as an empty cart — there is nothing meaningful to show yet.
final cartTotalItemsProvider = Provider<int>((ref) {
  return ref.watch(cartControllerProvider).valueOrNull?.itemCount ?? 0;
});
