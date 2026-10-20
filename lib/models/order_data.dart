import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';
import 'returns_data.dart';

/// How long an unpaid online order (`PLACED` / `PAYMENT_FAILED`) keeps its
/// stock held before the backend cancels it (`cancelledBy: "system"`).
const orderPaymentWindow = Duration(minutes: 30);

/// How long after placing it a `CONFIRMED` order can still be cancelled by
/// the customer (server setting `ORDER_CANCEL_WINDOW_HOURS`).
const orderCancelWindow = Duration(hours: 24);

/// What `POST /orders/checkout` (ONLINE) and `POST /orders/{id}/pay` hand
/// back — everything needed to open the Razorpay widget. The cart is **not**
/// cleared by either call; it stays as-is until payment actually confirms.
///
/// The app is prepaid only, so this is always the ONLINE shape.
class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.currency,
    required this.providerOrderId,
    required this.provider,
    required this.keyId,
    this.paymentMethod = 'ONLINE',
    this.customerId,
  });

  /// This is `{orderId}` in the order-status endpoints below.
  final String orderId;
  final String orderNumber;

  /// Whole rupees, matches what will be charged.
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

  /// Always `ONLINE` for this app.
  final String paymentMethod;

  /// Razorpay customer id. Passed to the sheet as `customer_id` so saved
  /// methods show and new ones can be saved. `null` when Razorpay was
  /// unreachable at checkout — payment still works, just without saving.
  final String? customerId;

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    return CheckoutOrder(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as String,
      amount: (json['amount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      providerOrderId: json['providerOrderId'] as String,
      provider: json['provider'] as String? ?? 'razorpay',
      keyId: json['keyId'] as String,
      paymentMethod: json['paymentMethod'] as String? ?? 'ONLINE',
      customerId: json['customerId'] as String?,
    );
  }
}

/// Every order status the backend can return. [unknown] is the deliberate
/// "don't crash" fallback for a status this build doesn't recognise yet —
/// it is shown as "Processing" (per the API contract), with the raw string
/// kept on the order alongside it.
enum OrderStatus {
  placed,
  paymentFailed,
  confirmed,
  packed,
  shipped,
  delivered,
  cancelled,
  returned,
  unknown,
}

OrderStatus parseOrderStatus(String? raw) => switch (raw) {
      'PLACED' => OrderStatus.placed,
      'PAYMENT_FAILED' => OrderStatus.paymentFailed,
      'CONFIRMED' => OrderStatus.confirmed,
      'PACKED' => OrderStatus.packed,
      'SHIPPED' => OrderStatus.shipped,
      'DELIVERED' => OrderStatus.delivered,
      'CANCELLED' => OrderStatus.cancelled,
      'RETURNED' => OrderStatus.returned,
      _ => OrderStatus.unknown,
    };

/// The customer-facing label — never the raw code (API contract, "Order
/// status reference"). [rawStatus] is accepted for call-site compatibility
/// but no longer shown: anything unknown reads "Processing".
String orderStatusLabel(OrderStatus status, [String rawStatus = '']) =>
    switch (status) {
      OrderStatus.placed => 'Awaiting payment',
      OrderStatus.paymentFailed => 'Payment failed',
      OrderStatus.confirmed => 'Order confirmed',
      OrderStatus.packed => 'Packed',
      OrderStatus.shipped => 'Shipped',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
      OrderStatus.returned => 'Returned',
      OrderStatus.unknown => 'Processing',
    };

/// Statuses that end the payment poll: anything that isn't still `PLACED`.
/// (`PAYMENT_FAILED` is terminal for the poll, not for the order — the order
/// can still be paid again via `POST /orders/{id}/pay`.)
bool isTerminalForPaymentPoll(OrderStatus status) =>
    status != OrderStatus.placed;

/// "Online" / "Cash on delivery" for the backend's `paymentMethod`. The app
/// only ever places ONLINE orders, but orders placed elsewhere may be COD.
String? paymentMethodLabel(String? method) => switch (method) {
      'ONLINE' => 'Online',
      'COD' => 'Cash on delivery',
      null || '' => null,
      _ => 'Online',
    };

/// Rules shared by [OrderSummary] and [Order] — what the customer can do
/// with an order right now. Each one mirrors a server-side check so the app
/// can hide an action the API would refuse; the API's `409` is still
/// handled at every call site for the races this can't see.
mixin OrderRules {
  OrderStatus get status;
  DateTime get createdAt;
  String? get paymentMethod;
  bool get accepted;

  bool get isCod => paymentMethod == 'COD';

  /// `PLACED` or `PAYMENT_FAILED`: stock held, waiting on payment.
  bool get awaitingPayment =>
      status == OrderStatus.placed || status == OrderStatus.paymentFailed;

  /// When the 30-minute payment window closes and the backend auto-cancels.
  DateTime get paymentDeadline => createdAt.add(orderPaymentWindow);

  /// Time left to pay, clamped at zero. Only meaningful while
  /// [awaitingPayment].
  Duration paymentTimeLeft([DateTime? now]) {
    final left = paymentDeadline.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// `POST /orders/{id}/pay` is allowed: an unpaid ONLINE order whose
  /// window hasn't closed yet.
  bool canPay([DateTime? now]) =>
      awaitingPayment &&
      !isCod &&
      paymentTimeLeft(now) > Duration.zero;

  /// `POST /orders/{id}/cancel` is allowed: `PLACED` / `PAYMENT_FAILED`, or
  /// `CONFIRMED` within 24 hours of placing it. Never once `PACKED`.
  bool canCancel([DateTime? now]) {
    if (awaitingPayment) return true;
    if (status != OrderStatus.confirmed) return false;
    return (now ?? DateTime.now()).isBefore(createdAt.add(orderCancelWindow));
  }

  /// `GET /orders/{id}/invoice` returns a PDF only for these.
  bool get hasInvoice => switch (status) {
        OrderStatus.confirmed ||
        OrderStatus.packed ||
        OrderStatus.shipped ||
        OrderStatus.delivered ||
        OrderStatus.returned =>
          true,
        _ => false,
      };

  /// Paid and confirmed, but the seller hasn't accepted it yet.
  bool get awaitingSellerAcceptance =>
      status == OrderStatus.confirmed && !accepted;
}

DateTime _parseDate(Object? raw) =>
    DateTime.tryParse(raw as String? ?? '')?.toLocal() ?? DateTime.now();

DateTime? _parseDateOrNull(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

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
    this.unit,
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
  final String? unit;
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
      unit: json['unit'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num?) ?? 0,
      totalPrice: (json['totalPrice'] as num?) ?? 0,
    );
  }
}

/// A row from `GET /orders` — deliberately lighter than [Order] (no line
/// items), so the order history list doesn't pay for every order's items and
/// images up front. Fetch [Order] for one when the user taps into it.
class OrderSummary with OrderRules {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.rawStatus,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.paymentMethod,
    this.paymentStatus,
    this.accepted = false,
  });

  final String id;
  final String orderNumber;
  @override
  final OrderStatus status;
  final String rawStatus;
  final num amount;
  final String currency;
  @override
  final DateTime createdAt;

  /// `ONLINE` / `COD`.
  @override
  final String? paymentMethod;

  /// Latest gateway attempt: `CREATED` / `CAPTURED` / `FAILED`; null for COD.
  final String? paymentStatus;

  /// The seller has accepted the order.
  @override
  final bool accepted;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['status'] as String? ?? '';
    return OrderSummary(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      status: parseOrderStatus(raw),
      rawStatus: raw,
      amount: (json['amount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt: _parseDate(json['createdAt']),
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      accepted: json['accepted'] as bool? ?? false,
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

/// Courier tracking from `shipment` on `GET /orders/{id}` — null until a
/// shipment is booked. Its [status] is independent of the order's.
class Shipment {
  const Shipment({
    required this.status,
    this.awbNumber,
    this.events = const [],
  });

  /// `CREATED` / `IN_TRANSIT` / `DELIVERED` / `RTO` / `FAILED`.
  final String status;
  final String? awbNumber;

  /// Oldest first.
  final List<TrackingEvent> events;

  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
        status: json['status'] as String? ?? '',
        awbNumber: json['awbNumber'] as String?,
        events: ((json['trackingEvents'] as List?) ?? const [])
            .map((e) => TrackingEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TrackingEvent {
  const TrackingEvent({
    required this.status,
    required this.occurredAt,
    this.description,
  });

  /// Shiprocket's raw uppercase string, e.g. `OUT FOR DELIVERY`.
  final String status;
  final String? description;
  final DateTime occurredAt;

  factory TrackingEvent.fromJson(Map<String, dynamic> json) => TrackingEvent(
        status: json['status'] as String? ?? '',
        description: json['description'] as String?,
        occurredAt: _parseDate(json['occurredAt']),
      );
}

/// Full order detail from `GET /orders/{id}`. `vendorAmount` /
/// `platformAmount` are the internal split and deliberately not parsed.
class Order with OrderRules {
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
    this.paymentMethod,
    this.paymentStatus,
    this.accepted = false,
    this.subtotal,
    this.discount = 0,
    this.acceptedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.deliveredAt,
    this.returnableUntil,
    this.returns = const [],
    this.shipment,
  });

  final String id;
  final String orderNumber;
  @override
  final OrderStatus status;
  final String rawStatus;

  /// What's payable: `subtotal − discount`.
  final num amount;
  final String currency;
  @override
  final DateTime createdAt;
  final List<OrderItem> items;

  /// `null` only for orders placed before addresses existed.
  final OrderAddress? address;

  @override
  final String? paymentMethod;
  final String? paymentStatus;
  @override
  final bool accepted;

  /// Sum of line totals. Null on responses that predate the field — use
  /// [itemsTotal] to read it.
  final num? subtotal;

  /// Coupon saving.
  final num discount;

  final DateTime? acceptedAt;
  final DateTime? cancelledAt;

  /// `customer` / `vendor` / `admin` / `system`.
  final String? cancelledBy;
  final String? cancelReason;

  final DateTime? deliveredAt;

  /// Last moment a return can be requested. Non-null only while `DELIVERED`.
  final DateTime? returnableUntil;

  /// Return requests on this order, newest first.
  final List<ReturnRequest> returns;

  final Shipment? shipment;

  /// "Return items" is offered: delivered, inside the window, and no other
  /// request still open.
  bool canReturn([DateTime? now]) =>
      status == OrderStatus.delivered &&
      returnableUntil != null &&
      (now ?? DateTime.now()).isBefore(returnableUntil!) &&
      !returns.any((r) => r.isOpen);

  num get itemsTotal =>
      subtotal ?? items.fold<num>(0, (sum, i) => sum + i.totalPrice);

  /// An online payment was captured — so a cancelled order was refunded.
  bool get wasPaidOnline => !isCod && paymentStatus == 'CAPTURED';

  factory Order.fromJson(Map<String, dynamic> json) {
    final raw = json['status'] as String? ?? '';
    return Order(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      status: parseOrderStatus(raw),
      rawStatus: raw,
      amount: (json['amount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt: _parseDate(json['createdAt']),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      address: json['address'] == null
          ? null
          : OrderAddress.fromJson(json['address'] as Map<String, dynamic>),
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      accepted: json['accepted'] as bool? ?? false,
      subtotal: json['subtotal'] as num?,
      discount: (json['discount'] as num?) ?? 0,
      acceptedAt: _parseDateOrNull(json['acceptedAt']),
      cancelledAt: _parseDateOrNull(json['cancelledAt']),
      cancelledBy: json['cancelledBy'] as String?,
      cancelReason: json['cancelReason'] as String?,
      deliveredAt: _parseDateOrNull(json['deliveredAt']),
      returnableUntil: _parseDateOrNull(json['returnableUntil']),
      returns: ((json['returns'] as List?) ?? const [])
          .map((e) => ReturnRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      shipment: json['shipment'] == null
          ? null
          : Shipment.fromJson(json['shipment'] as Map<String, dynamic>),
    );
  }
}

/// Who cancelled, in words: "You cancelled this order", etc.
String? cancelledByLabel(String? by) => switch (by) {
      'customer' => 'Cancelled by you',
      'vendor' => 'Cancelled by the seller',
      'admin' => 'Cancelled by IrriKart',
      'system' => 'Cancelled automatically',
      _ => null,
    };

/// `refundStatus` from `POST /orders/{id}/cancel`.
enum RefundStatus {
  /// Nothing was charged (unpaid order, or COD).
  none,

  /// `pending` / `processed` — the refund has started.
  started,

  /// The gateway refused; the team follows up from the admin dashboard.
  failed,
}

RefundStatus parseRefundStatus(String? raw) => switch (raw) {
      null || '' => RefundStatus.none,
      'failed' => RefundStatus.failed,
      _ => RefundStatus.started,
    };

/// The message to show after a successful cancel.
String cancelOutcomeMessage(RefundStatus refund) => switch (refund) {
      RefundStatus.none => 'Order cancelled',
      RefundStatus.started =>
        'Order cancelled. Refund started to your original payment method.',
      RefundStatus.failed =>
        'Order cancelled. Your refund is being processed manually.',
    };

/// `POST /orders/{id}/cancel` → the cancelled order plus how the refund went.
class CancelResult {
  const CancelResult({required this.order, required this.refundStatus});

  final Order order;
  final RefundStatus refundStatus;

  factory CancelResult.fromJson(Map<String, dynamic> json) => CancelResult(
        order: Order.fromJson(json),
        refundStatus: parseRefundStatus(json['refundStatus'] as String?),
      );
}

/// A line `POST /orders/{id}/reorder` couldn't put back in the cart (same
/// shape as cart merge's `skipped`). [reason] is user-facing.
class SkippedLine {
  const SkippedLine({
    required this.variantId,
    required this.quantity,
    required this.reason,
  });

  final String variantId;
  final int quantity;
  final String reason;

  factory SkippedLine.fromJson(Map<String, dynamic> json) => SkippedLine(
        variantId: json['variantId'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? 'Couldn’t be added',
      );
}

/// `POST /orders/{id}/reorder` → `{cart, skipped}`. The cart itself is
/// re-read through `cartControllerProvider.refresh()`, so only [skipped] is
/// kept here.
class ReorderResult {
  const ReorderResult({required this.skipped});

  final List<SkippedLine> skipped;

  factory ReorderResult.fromJson(Map<String, dynamic> json) => ReorderResult(
        skipped: ((json['skipped'] as List?) ?? const [])
            .map((e) => SkippedLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A coupon from `GET /discounts/offers` — one the caller can apply now.
class CouponOffer {
  const CouponOffer({
    required this.code,
    required this.type,
    required this.value,
    this.description,
    this.minCartValue,
    this.expiresAt,
    this.firstOrderOnly = false,
    this.personal = false,
  });

  final String code;
  final String? description;

  /// `FLAT` (rupees off) or `PERCENT` (of the subtotal).
  final String type;
  final num value;
  final num? minCartValue;
  final DateTime? expiresAt;
  final bool firstOrderOnly;

  /// Issued to this customer alone.
  final bool personal;

  /// "₹50 off" / "10% off".
  String get headline => type == 'PERCENT'
      ? '${value % 1 == 0 ? value.toInt() : value}% off'
      : '₹${value % 1 == 0 ? value.toInt() : value} off';

  factory CouponOffer.fromJson(Map<String, dynamic> json) => CouponOffer(
        code: json['code'] as String,
        description: json['description'] as String?,
        type: json['type'] as String? ?? 'FLAT',
        value: (json['value'] as num?) ?? 0,
        minCartValue: json['minCartValue'] as num?,
        expiresAt: _parseDateOrNull(json['expiresAt']),
        firstOrderOnly: json['firstOrderOnly'] as bool? ?? false,
        personal: json['personal'] as bool? ?? false,
      );
}

/// Checkout and order history — one repository, since the contract puts all
/// of these under the same `/orders` resource. User-scoped and auth-only,
/// same as the cart.
class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  /// Places the order from the caller's **current cart** — there is no
  /// separate "build an order" step. This has side effects even before
  /// payment (re-validates stock/price live and **reserves stock**), so only
  /// call it on the user's explicit "place order" tap, never speculatively.
  ///
  /// The app is prepaid only: `paymentMethod` is always sent as `ONLINE`.
  Future<CheckoutOrder> checkout({
    required String addressId,
    String? couponCode,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/orders/checkout',
          data: {
            'addressId': addressId,
            'paymentMethod': 'ONLINE',
            if (couponCode != null && couponCode.isNotEmpty)
              'couponCode': couponCode,
          },
        ),
        (data) => CheckoutOrder.fromJson(data as Map<String, dynamic>),
      );

  /// Reopens payment for a `PLACED` / `PAYMENT_FAILED` order — the same
  /// Razorpay order as the original checkout, so never send the user back
  /// through [checkout] to retry (that would create a second order).
  ///
  /// `409` when the order was cancelled/expired or is already paid.
  Future<CheckoutOrder> payOrder(String orderId) => _call(
        () => _dio.post<dynamic>('/orders/$orderId/pay'),
        (data) => CheckoutOrder.fromJson(data as Map<String, dynamic>),
      );

  /// Confirms a payment the moment the checkout SDK reports success, instead
  /// of waiting on Razorpay's webhook to reach the backend.
  ///
  /// Returns just the resulting status (`CONFIRMED`, `PAYMENT_FAILED`, or
  /// still `PLACED` if the gateway hasn't settled it yet — poll [getOrder]
  /// then).
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
        (data) => parseOrderStatus(
          (data as Map<String, dynamic>)['status'] as String?,
        ),
      );

  /// Poll this after the payment SDK closes (every 2–3s, up to 60s) until
  /// [Order.status] leaves [OrderStatus.placed].
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

  /// [reason] must be 3–500 characters (trimmed).
  Future<CancelResult> cancelOrder(String orderId, String reason) => _call(
        () => _dio.post<dynamic>(
          '/orders/$orderId/cancel',
          data: {'reason': reason.trim()},
        ),
        (data) => CancelResult.fromJson(data as Map<String, dynamic>),
      );

  Future<List<CouponOffer>> listOffers() => _call(
        () => _dio.get<dynamic>('/discounts/offers'),
        (data) => (data as List)
            .map((e) => CouponOffer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<ReorderResult> reorder(String orderId) => _call(
        () => _dio.post<dynamic>('/orders/$orderId/reorder'),
        (data) => ReorderResult.fromJson(data as Map<String, dynamic>),
      );

  /// The invoice PDF's bytes. `409` until the order is confirmed (and for
  /// cancelled orders). The error body is still the JSON envelope, so it's
  /// decoded by hand from the raw bytes.
  Future<Uint8List> downloadInvoice(String orderId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/orders/$orderId/invoice',
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'application/pdf'},
        ),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) {
        throw const ApiException(
          null,
          'No internet connection. Check your network and try again.',
        );
      }
      if (response.statusCode == 401) throw const AuthRequiredException();
      throw ApiException(
        response.statusCode,
        _messageFromBytes(response.data) ??
            'Something went wrong. Please try again.',
      );
    }
  }

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

String? _messageFromBytes(Object? data) {
  try {
    final text = switch (data) {
      final List<int> bytes => utf8.decode(bytes),
      final String s => s,
      _ => null,
    };
    if (text == null) return null;
    final body = jsonDecode(text);
    return body is Map ? body['message'] as String? : null;
  } catch (_) {
    return null;
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

final couponOffersProvider = FutureProvider.autoDispose<List<CouponOffer>>(
  (ref) => ref.watch(ordersRepositoryProvider).listOffers(),
);

/// The `refundStatus` of orders cancelled in this session, by order id —
/// `GET /orders/{id}` doesn't carry it, so the detail screen reads it here
/// to keep showing "being processed manually" after a failed refund.
final cancelRefundStatusProvider =
    StateProvider<Map<String, RefundStatus>>((ref) => const {});

/// A message safe to show a user for any error an order call can throw.
/// Branches on the HTTP status, never on the message text.
String orderErrorMessage(Object error) {
  if (error is AuthRequiredException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (error is ApiException) {
    if (error.isServerError) return 'Something went wrong. Please try again.';
    if (error.statusCode == 429) {
      return 'Too many requests right now. Please wait a moment and try again.';
    }
    // 400/404/409: the backend's message is written for end users.
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}
