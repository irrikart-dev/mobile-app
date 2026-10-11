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

  /// Signed-out lines live on the device with a synthetic id (see
  /// [guestLineId]) rather than a server one.
  bool get isGuest => id.startsWith(guestLinePrefix);

  static const guestLinePrefix = 'guest:';

  static String guestLineId(String variantId) => '$guestLinePrefix$variantId';

  CartLine copyWith({
    String? name,
    String? slug,
    String? productId,
    String? image,
    String? sku,
    String? unit,
    int? quantity,
    num? price,
    int? available,
  }) {
    final q = quantity ?? this.quantity;
    final p = price ?? this.price;
    return CartLine(
      id: id,
      variantId: variantId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      image: image ?? this.image,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      quantity: q,
      price: p,
      lineTotal: p * q,
      available: available ?? this.available,
    );
  }

  /// The guest-cart persistence shape (see `LocalStore.guestCart`) — the
  /// `{variantId, quantity}` the merge needs plus a display snapshot.
  Map<String, dynamic> toGuestJson() => {
        'variantId': variantId,
        'quantity': quantity,
        'productId': productId,
        'name': name,
        'slug': slug,
        'image': image,
        'sku': sku,
        'unit': unit,
        'price': price,
        'available': available,
      };

  factory CartLine.fromGuestJson(Map<String, dynamic> json) {
    final variantId = json['variantId'] as String;
    final quantity = (json['quantity'] as num).toInt();
    final price = (json['price'] as num?) ?? 0;
    return CartLine(
      id: guestLineId(variantId),
      variantId: variantId,
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      image: json['image'] as String?,
      sku: json['sku'] as String? ?? '',
      unit: json['unit'] as String? ?? 'piece',
      quantity: quantity,
      price: price,
      lineTotal: price * quantity,
      available: (json['available'] as num?)?.toInt() ?? quantity,
    );
  }

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

/// A guest-cart line the server refused during `POST /cart/merge` — gone,
/// short on stock (skipped whole, never reduced) or from a different seller.
@immutable
class CartMergeSkip {
  const CartMergeSkip({
    required this.variantId,
    required this.quantity,
    required this.reason,
    this.name,
    this.image,
  });

  final String variantId;
  final int quantity;

  /// The server's user-facing explanation — show as-is.
  final String reason;

  /// From the guest line's snapshot; the server only echoes the variant id.
  final String? name;
  final String? image;

  factory CartMergeSkip.fromJson(Map<String, dynamic> json) => CartMergeSkip(
        variantId: json['variantId'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ??
            'This item couldn’t be added to your cart.',
      );
}

/// `POST /cart/merge`'s `{ cart, skipped }`.
typedef CartMergeResult = ({Cart cart, List<CartMergeSkip> skipped});

/// Every cart endpoint is user-scoped and auth-only — the server has no
/// guest mode. Signed-out carts live on the device (see [CartController])
/// and reach the server once, through [merge], after sign-in. The Dio
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

  /// Max lines per `POST /cart/merge`.
  static const mergeLimit = 100;

  /// Adds guest [lines] onto the server cart (additively, like
  /// [addItem]). Lines it can't add come back in `skipped`; the rest still
  /// merge. More than [mergeLimit] lines go up in several calls.
  Future<CartMergeResult> merge(
    List<({String variantId, int quantity})> lines,
  ) async {
    var cart = Cart.empty;
    final skipped = <CartMergeSkip>[];
    for (var i = 0; i < lines.length; i += mergeLimit) {
      final chunk = lines.skip(i).take(mergeLimit);
      try {
        final result = await apiRequest(
          () => _dio.post<dynamic>(
            '/cart/merge',
            data: {
              'items': [
                for (final l in chunk)
                  {'variantId': l.variantId, 'quantity': l.quantity},
              ],
            },
          ),
          (data) {
            final map = data as Map<String, dynamic>;
            return (
              cart: Cart.fromJson(map['cart'] as Map<String, dynamic>),
              skipped: ((map['skipped'] as List?) ?? const [])
                  .map((e) => CartMergeSkip.fromJson(e as Map<String, dynamic>))
                  .toList(),
            );
          },
        );
        cart = result.cart;
        skipped.addAll(result.skipped);
      } on ApiException catch (e) {
        if (e.isUnauthorized) throw const AuthRequiredException();
        rethrow;
      }
    }
    return (cart: cart, skipped: skipped);
  }

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

/// The cart — whoever is (or isn't) signed in, behind one API.
///
/// - **Signed in:** the server cart (`/cart`).
/// - **Signed out:** a local cart persisted on the device
///   (`LocalStore.guestCart`) with the same [Cart]/[CartLine] shape, line
///   ids `guest:<variantId>`, and display data (name, image, price, unit,
///   available stock) taken from the catalogue. [add], [setQuantity],
///   [remove] and [clear] behave the same as against the server, including
///   the `409`-style "Only N available" refusal.
/// - **On sign-in** (this rebuilds on auth changes): the guest lines are
///   posted once to `POST /cart/merge`, the device copy is cleared and the
///   merged cart shown. Lines the server refused land in
///   [cartMergeSkippedProvider] for the cart screen to explain once.
class CartController extends AsyncNotifier<Cart> {
  // Line ids with a remove/quantity request currently in flight — guards
  // against a rapid double-tap firing two overlapping requests for the same
  // line (the optimistic update below makes a second tap feel free, so
  // without this a fast double-tap could race two PATCH/DELETE calls).
  final Set<String> _pendingLineIds = {};

  @override
  Future<Cart> build() async {
    if (!ref.watch(isSignedInProvider)) {
      // Watched only while signed out: a catalogue refresh re-prices guest
      // lines, but never refetches the server cart.
      return _guestCart(ref.watch(catalogDataProvider).valueOrNull);
    }
    final merged = await _mergeGuestCart();
    return merged ?? ref.read(cartRepositoryProvider).fetch();
  }

  bool get _signedIn => ref.read(isSignedInProvider);

  LocalStore get _store => ref.read(localStoreProvider);

  // ---- guest cart ----------------------------------------------------------

  List<CartLine> _readGuestLines() {
    final lines = <CartLine>[];
    for (final json in _store.guestCart) {
      try {
        final line = CartLine.fromGuestJson(json);
        if (line.variantId.isNotEmpty && line.quantity > 0) lines.add(line);
      } catch (_) {
        // A malformed entry is dropped, not fatal.
      }
    }
    return lines;
  }

  /// The device cart, re-priced from [data] when the catalogue is loaded.
  Cart _guestCart(CatalogData? data) {
    final lines = [
      for (final line in _readGuestLines())
        data == null ? line : refreshGuestLine(line, data),
    ];
    return _withLines(Cart.empty, lines);
  }

  Cart _saveGuest(List<CartLine> lines) {
    unawaited(_store.setGuestCart([for (final l in lines) l.toGuestJson()]));
    return _withLines(Cart.empty, lines);
  }

  Future<CatalogData?> _catalog() async {
    try {
      return ref.read(catalogDataProvider).valueOrNull ??
          await ref.read(catalogDataProvider.future);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guestAdd(String variantId, int quantity) async {
    final data = await _catalog();
    final match = data?.findVariant(variantId);
    if (match == null) {
      // No live variant id (offline fixtures) — nothing the server could
      // ever merge, so refuse now rather than at sign-in.
      throw const ApiException(
        null,
        'Couldn’t add this item right now. Check your connection and try again.',
      );
    }
    // The device copy, not [state] — state can briefly still hold the
    // server cart while a sign-out rebuild is in flight.
    final lines = [..._guestCart(data).items];
    final index = lines.indexWhere((l) => l.variantId == variantId);
    final fresh = guestLineFor(match.product, match.variant, quantity);
    final wanted = (index >= 0 ? lines[index].quantity : 0) + quantity;
    if (wanted > fresh.available) {
      throw ApiException(409, 'Only ${fresh.available} of this item available');
    }
    if (index >= 0) {
      lines[index] = fresh.copyWith(quantity: wanted);
    } else {
      lines.add(fresh);
    }
    state = AsyncData(_saveGuest(lines));
  }

  // ---- sign-in merge -------------------------------------------------------

  /// Posts the guest cart to `POST /cart/merge` if there is one. Null when
  /// there was nothing to merge, or the merge couldn't reach the server (the
  /// device copy is then kept for the next attempt).
  Future<Cart?> _mergeGuestCart() async {
    final guest = _readGuestLines();
    if (guest.isEmpty) return null;
    try {
      final result = await ref.read(cartRepositoryProvider).merge([
        for (final l in guest) (variantId: l.variantId, quantity: l.quantity),
      ]);
      await _store.setGuestCart(const []);
      ref.read(cartMergeSkippedProvider.notifier).state =
          describeSkipped(result.skipped, guest);
      return result.cart;
    } on ApiException catch (e) {
      // A 400 means the payload itself is unmergeable — retrying forever
      // wouldn't help, so let it go. Anything else (offline, 5xx) is kept.
      if (e.statusCode == 400) await _store.setGuestCart(const []);
      debugPrint('IrriKart: guest cart merge failed ($e)');
      return null;
    }
  }

  // ---- public API ----------------------------------------------------------

  /// Re-fetches from the server, bypassing whatever is currently held —
  /// always do this immediately before checkout (see the cart contract's
  /// "re-fetch before checkout" rule). Signed out, re-reads the device cart.
  Future<void> refresh() async {
    if (!_signedIn) {
      state = AsyncData(_guestCart(await _catalog()));
      return;
    }
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => ref.read(cartRepositoryProvider).fetch());
  }

  Future<void> add(String variantId, {int quantity = 1}) async {
    if (!_signedIn) return _guestAdd(variantId, quantity);
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
    if (!_signedIn) {
      final current = _guestCart(ref.read(catalogDataProvider).valueOrNull);
      final line = current.items.where((l) => l.id == itemId).firstOrNull;
      if (line == null) {
        throw const ApiException(404, 'That item is no longer in your cart.');
      }
      if (quantity > line.available) {
        throw ApiException(
          409,
          'Only ${line.available} of this item available',
        );
      }
      state = AsyncData(
        _saveGuest(_withUpdatedQuantity(current, itemId, quantity).items),
      );
      return;
    }
    if (!_pendingLineIds.add(itemId)) return;
    final previous = state;
    final current = previous.valueOrNull;
    if (current != null) {
      state = AsyncData(_withUpdatedQuantity(current, itemId, quantity));
    }
    try {
      final cart = await ref
          .read(cartRepositoryProvider)
          .updateQuantity(itemId, quantity);
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
    if (!_signedIn) {
      final current = _guestCart(ref.read(catalogDataProvider).valueOrNull);
      state = AsyncData(_saveGuest(_withoutLine(current, itemId).items));
      return;
    }
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
    if (!_signedIn) {
      state = AsyncData(_saveGuest(const []));
      return;
    }
    final cart = await ref.read(cartRepositoryProvider).clear();
    state = AsyncData(cart);
  }
}

/// A guest line for [variant] of [product] (or the product's default
/// variant when [variant] is null), with display data from the catalogue.
@visibleForTesting
CartLine guestLineFor(
  CatalogProduct product,
  CatalogVariant? variant,
  int quantity,
) {
  final variantId = variant?.id ?? product.variantId;
  final price = variant?.price ?? product.price;
  return CartLine(
    id: CartLine.guestLineId(variantId),
    variantId: variantId,
    productId: product.id,
    name: product.name,
    slug: product.slug,
    image: product.displayImage,
    sku: variant?.sku ?? product.sku,
    unit: variant?.unit ?? product.unit,
    quantity: quantity,
    price: price,
    lineTotal: price * quantity,
    available: variant?.available ?? (product.buyable ? product.stockQty : 0),
  );
}

/// Re-prices a stored guest line from the current catalogue; unchanged
/// when its variant is no longer listed (the merge will report it).
@visibleForTesting
CartLine refreshGuestLine(CartLine line, CatalogData data) {
  final match = data.findVariant(line.variantId);
  if (match == null) return line;
  return guestLineFor(match.product, match.variant, line.quantity);
}

/// Attaches each skipped line's name/image from the guest snapshot (the
/// server only echoes `variantId`).
@visibleForTesting
List<CartMergeSkip> describeSkipped(
  List<CartMergeSkip> skipped,
  List<CartLine> guest,
) {
  return [
    for (final s in skipped)
      () {
        final line = guest.where((l) => l.variantId == s.variantId).firstOrNull;
        return CartMergeSkip(
          variantId: s.variantId,
          quantity: s.quantity,
          reason: s.reason,
          name: line?.name,
          image: line?.image,
        );
      }(),
  ];
}

/// Guest-cart lines the sign-in merge couldn't add, each with the server's
/// reason. The cart screen shows them once, then sets this back to `[]`.
final cartMergeSkippedProvider =
    StateProvider<List<CartMergeSkip>>((ref) => const []);

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

/// Cart tab badge — the guest cart's count when signed out. `0` while the
/// cart is loading, same as an empty cart.
final cartTotalItemsProvider = Provider<int>((ref) {
  return ref.watch(cartControllerProvider).valueOrNull?.itemCount ?? 0;
});
