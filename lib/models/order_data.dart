import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

/// What `POST /orders/checkout` hands back — everything needed to open the
/// Razorpay widget. The cart is **not** cleared by this call; it stays as-is
/// until payment actually confirms (see [Order.status]).
class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.currency,
    required this.providerOrderId,
    required this.provider,
    required this.keyId,
  });

  /// This is `{orderId}` in the order-status endpoints below.
  final String orderId;
  final String orderNumber;

  /// Whole rupees, matches what was charged.
  final num amount;
  final String currency;

  /// Pass straight through to the payment SDK as its order id.
  final String providerOrderId;

  /// Which gateway is active. Always `"razorpay"` today — deliberately not
  /// hardcoded so a future gateway switch doesn't need an app change here,
  /// but [openRazorpayCheckout] (`core/payments/razorpay_checkout.dart`) is
  /// the one place that would need a branch if it's ever anything else.
  final String provider;

  /// Gateway's publishable key — pass straight through to the SDK.
  final String keyId;

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    return CheckoutOrder(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as String,
      amount: (json['amount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      providerOrderId: json['providerOrderId'] as String,
      provider: json['provider'] as String? ?? 'razorpay',
      keyId: json['keyId'] as String,
    );
  }
}

/// Only `placed` -> `confirmed`/`cancelled` matters for the payment flow.
/// The rest are fulfillment states for a future order-tracking screen.
/// [unknown] is the deliberate "don't crash" fallback for a status this
/// build doesn't recognise yet — the order's own `rawStatus` is kept
/// alongside it so it still displays as *something* sensible.
enum OrderStatus {
  placed,
  confirmed,
  packed,
  shipped,
  delivered,
  cancelled,
  returned,
  unknown,
}

OrderStatus _parseOrderStatus(String raw) => switch (raw) {
      'PLACED' => OrderStatus.placed,
      'CONFIRMED' => OrderStatus.confirmed,
      'PACKED' => OrderStatus.packed,
      'SHIPPED' => OrderStatus.shipped,
      'DELIVERED' => OrderStatus.delivered,
      'CANCELLED' => OrderStatus.cancelled,
      'RETURNED' => OrderStatus.returned,
      _ => OrderStatus.unknown,
    };

/// A display label for [status] — falls back to the server's own
/// [rawStatus] string for anything this build doesn't have copy for yet.
String orderStatusLabel(OrderStatus status, String rawStatus) =>
    switch (status) {
      OrderStatus.placed => 'Placed',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.packed => 'Packed',
      OrderStatus.shipped => 'Shipped',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
      OrderStatus.returned => 'Returned',
      OrderStatus.unknown => rawStatus.isEmpty ? 'Unknown' : rawStatus,
    };

/// One line item on a placed order, from `GET /orders/{id}`.
///
/// [unitPrice]/[totalPrice] are the price actually charged — snapshotted at
/// checkout, not the product's current live price. Always show these,
/// never re-fetch the catalogue price for a placed order.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.name,
    required this.slug,
    required this.image,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  /// This order item's own id — distinct from [variantId]/[productId]. Use
  /// this, not either of those, as `orderItemId` when submitting a review.
  final String id;
  final String variantId;
  final String productId;
  final String name;
  final String slug;

  /// Absolute URL, same convention as the catalogue's `imageUrl`. `null`
  /// means render a placeholder.
  final String? image;

  final String sku;
  final int quantity;
  final num unitPrice;
  final num totalPrice;

  bool get hasRemoteImage => image != null && image!.isNotEmpty;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      productId: json['productId'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      image: json['image'] as String?,
      sku: json['sku'] as String? ?? '',
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num?) ?? 0,
      totalPrice: (json['totalPrice'] as num?) ?? 0,
    );
  }
}

/// A row from `GET /orders` — deliberately lighter than [Order] (no line
/// items), so the order history list doesn't pay for every order's items and
/// images up front. Fetch [Order] for one when the user taps into it.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.rawStatus,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String rawStatus;
  final num amount;
  final String currency;
  final DateTime createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['status'] as String? ?? '';
    return OrderSummary(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      status: _parseOrderStatus(raw),
      rawStatus: raw,
      amount: (json['amount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

/// The address an order shipped to — a snapshot at order time, distinct
/// from the (editable, deletable) saved [Address] it was created from.
class OrderAddress {
  const OrderAddress({
    required this.name,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.pincode,
  });

  final String name;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;

  String get oneLine => '$line1, $city, $state $pincode';

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
    );
  }
}

/// Full order detail from `GET /orders/{id}`.
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.rawStatus,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.items,
    required this.address,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String rawStatus;
  final num amount;
  final String currency;
  final DateTime createdAt;
  final List<OrderItem> items;

  /// `null` only for orders placed before addresses existed.
  final OrderAddress? address;

  factory Order.fromJson(Map<String, dynamic> json) {
    final raw = json['status'] as String? ?? '';
    return Order(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      status: _parseOrderStatus(raw),
      rawStatus: raw,
      amount: (json['amount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      address: json['address'] == null
          ? null
          : OrderAddress.fromJson(json['address'] as Map<String, dynamic>),
    );
  }
}

/// Checkout and order history — one repository, since the contract puts all
/// three endpoints under the same `/orders` resource. User-scoped and
/// auth-only, same as the cart.
class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  /// Places the order from the caller's **current cart** — there is no
  /// separate "build an order" step, and no body fields beyond an optional
  /// coupon. This has side effects even before payment (re-validates
  /// stock/price live and **reserves stock**), so only call it on the user's
  /// explicit "place order" tap, never speculatively.
  Future<CheckoutOrder> checkout({
    required String addressId,
    String? couponCode,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/orders/checkout',
          data: {
            'addressId': addressId,
            if (couponCode != null && couponCode.isNotEmpty)
              'couponCode': couponCode,
          },
        ),
        (data) => CheckoutOrder.fromJson(data as Map<String, dynamic>),
      );

  /// Confirms a payment the moment the checkout SDK reports success, instead
  /// of waiting on Razorpay's webhook to reach the backend — call this first,
  /// right after [RazorpayCheckoutResult.canVerify] is true, and only fall
  /// back to polling [getOrder] if it isn't (an external-wallet handoff has
  /// no payment id yet) or this itself fails (network blip — the webhook is
  /// still coming regardless).
  ///
  /// Returns just the resulting status, not a full [Order] — the backend's
  /// response here is intentionally light (`{orderId, status}`). Once this
  /// comes back anything other than [OrderStatus.placed], call [getOrder] for
  /// the full order to actually show. [OrderStatus.placed] here still means
  /// "not settled yet," not "verify failed" — the gateway hadn't captured the
  /// payment at the moment of the call, and the webhook will finish it.
  Future<OrderStatus> verifyPayment({
    required String orderId,
    required String providerPaymentId,
    required String signature,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/payments/verify',
          data: {
            'orderId': orderId,
            'providerPaymentId': providerPaymentId,
            'signature': signature,
          },
        ),
        (data) => _parseOrderStatus(
          (data as Map<String, dynamic>)['status'] as String,
        ),
      );

  /// Poll this after the payment SDK's callback fires (every 2-3s is
  /// reasonable) until [Order.status] leaves [OrderStatus.placed] — the SDK
  /// callback only means Razorpay accepted the payment client-side, not that
  /// the order is confirmed. See the checkout contract §4.
  Future<Order> getOrder(String orderId) => _call(
        () => _dio.get<dynamic>('/orders/$orderId'),
        (data) => Order.fromJson(data as Map<String, dynamic>),
      );

  /// Newest first, capped at 50 — no pagination yet.
  Future<List<OrderSummary>> listOrders() => _call(
        () => _dio.get<dynamic>('/orders'),
        (data) => (data as List)
            .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      return await apiRequest(request, parse);
    } on ApiException catch (e) {
      if (e.isUnauthorized) throw const AuthRequiredException();
      rethrow;
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref.watch(dioProvider)),
);

final orderHistoryProvider = FutureProvider<List<OrderSummary>>(
  (ref) => ref.watch(ordersRepositoryProvider).listOrders(),
);

final orderDetailProvider = FutureProvider.family<Order, String>(
  (ref, orderId) => ref.watch(ordersRepositoryProvider).getOrder(orderId),
);

/// A message safe to show a user for any error an order call can throw.
String orderErrorMessage(Object error) {
  if (error is AuthRequiredException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (error is ApiException) {
    // The backend's own message already names the specific problem — an
    // empty cart, an invalid coupon, insufficient stock, or "not your
    // order" — so there is nothing more specific to add generically here.
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}
