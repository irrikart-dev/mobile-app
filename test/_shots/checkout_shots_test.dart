@Tags(['shots'])
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/entry_point.dart';
import 'package:irrikart/entry_point_tab.dart';
import 'package:irrikart/models/address_data.dart';
import 'package:irrikart/models/cart_state.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/order_data.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/screens/checkout/views/cart_screen.dart';
import 'package:irrikart/screens/checkout/views/checkout_screen.dart';
import 'package:irrikart/screens/checkout/views/order_processing_screen.dart';
import 'package:irrikart/screens/checkout/views/thanks_for_order_screen.dart';
import 'package:irrikart/screens/order/views/order_detail_screen.dart';

import 'harness.dart';

const _img = 'assets/mock/products';
const _images = [
  '$_img/img003-1-1-600x600.jpg',
  '$_img/img018-rps-select-pr.jpg',
  '$_img/img009-Untitled-design-2-600x600.jpg',
];

CartLine _line(int i, String name, num price, int qty, {int available = 50}) =>
    CartLine(
      id: 'l$i',
      variantId: 'v$i',
      productId: 'p$i',
      name: name,
      slug: 's$i',
      image: _images[i],
      sku: 'SKU$i',
      unit: 'piece',
      quantity: qty,
      price: price,
      lineTotal: price * qty,
      available: available,
    );

Cart _cart({bool short = false}) {
  final items = [
    _line(0, 'Double Union Ball Valve 2″', 649, 2),
    _line(1, 'RPS Select Rain Pipe Sprinkler System', 1899, 1,
        available: short ? 0 : 20,),
    _line(2, 'Hans™ Plastic Sprinkler', 249, 4),
  ];
  final total = items.fold<num>(0, (s, l) => s + l.lineTotal);
  return Cart(
    id: 'c1',
    status: 'ACTIVE',
    items: items,
    itemCount: items.fold<int>(0, (s, l) => s + l.quantity),
    subtotal: total,
    total: total,
  );
}

class _FakeCart extends CartController {
  _FakeCart(this.cart);
  final Cart cart;
  @override
  Future<Cart> build() async => cart;
  @override
  Future<void> refresh() async => state = AsyncData(cart);
}

const _address = Address(
  id: 'a1',
  name: 'Ramesh Patil',
  phone: '+91 98220 41234',
  line1: 'Gat No. 214, Shivaji Nagar',
  line2: 'Near Gram Panchayat',
  city: 'Baramati',
  state: 'Maharashtra',
  pincode: '413102',
  isDefault: true,
);

class _FakeAddresses extends AddressController {
  @override
  Future<List<Address>> build() async => const [_address];
}

class _FakeOrdersRepo extends OrdersRepository {
  _FakeOrdersRepo() : super(Dio());
  @override
  Future<OrderStatus> verifyPayment({
    required String orderId,
    required String providerPaymentId,
    required String signature,
  }) =>
      Completer<OrderStatus>().future;
}

final _order = Order(
  id: 'o1',
  orderNumber: 'IK-10427',
  status: OrderStatus.shipped,
  rawStatus: 'SHIPPED',
  amount: 4193,
  currency: 'INR',
  createdAt: DateTime(2026, 10, 4, 15, 45),
  items: [
    for (var i = 0; i < 3; i++)
      OrderItem(
        id: 'oi$i',
        variantId: 'v$i',
        productId: 'p$i',
        name: [
          'Double Union Ball Valve 2″',
          'RPS Select Rain Pipe Sprinkler System',
          'Hans™ Plastic Sprinkler',
        ][i],
        slug: 's$i',
        image: _images[i],
        sku: 'SKU$i',
        quantity: [2, 1, 4][i],
        unitPrice: [649, 1899, 249][i],
        totalPrice: [1298, 1899, 996][i],
      ),
  ],
  address: const OrderAddress(
    name: 'Ramesh Patil',
    phone: '+91 98220 41234',
    line1: 'Gat No. 214, Shivaji Nagar',
    line2: 'Near Gram Panchayat',
    city: 'Baramati',
    state: 'Maharashtra',
    pincode: '413102',
  ),
);

OrderSummary _summary(int i, OrderStatus s, num amount, DateTime at) =>
    OrderSummary(
      id: 'o$i',
      orderNumber: 'IK-${10427 - i * 13}',
      status: s,
      rawStatus: s.name.toUpperCase(),
      amount: amount,
      currency: 'INR',
      createdAt: at,
    );

final _orders = [
  _summary(0, OrderStatus.shipped, 4193, DateTime(2026, 10, 4)),
  _summary(1, OrderStatus.confirmed, 1298, DateTime(2026, 9, 28)),
  _summary(2, OrderStatus.delivered, 12450, DateTime(2026, 9, 12)),
  _summary(3, OrderStatus.delivered, 899, DateTime(2026, 8, 30)),
  _summary(4, OrderStatus.cancelled, 2199, DateTime(2026, 8, 2)),
];

List<Override> _base({bool short = false}) => [
      isSignedInProvider.overrideWithValue(true),
      catalogDataProvider.overrideWith((ref) => CatalogData.loadBundled()),
      cartControllerProvider.overrideWith(() => _FakeCart(_cart(short: short))),
      addressControllerProvider.overrideWith(_FakeAddresses.new),
      ordersRepositoryProvider.overrideWithValue(_FakeOrdersRepo()),
      orderHistoryProvider.overrideWith((ref) async => _orders),
      orderDetailProvider.overrideWith((ref, id) async => _order),
    ];

Future<void> _precache(WidgetTester t) async {
  await t.runAsync(() async {
    final ctx = t.element(find.byType(Scaffold).last);
    for (final p in _images) {
      await precacheImage(AssetImage(p), ctx);
    }
  });
  await t.pump(const Duration(milliseconds: 100));
}

/// Pushes [screen] over a blank root so it gets a back button / real route.
Future<void> Function(WidgetTester) _push(Widget screen, String name) =>
    (t) async {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: name),
            builder: (_) => screen,
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await _precache(t);
    };

/// Runs [first] then scrolls the last vertical list to its end.
Future<void> Function(WidgetTester) _thenScroll(
  Future<void> Function(WidgetTester)? first,
) =>
    (t) async {
      if (first != null) await first(t);
      await t.drag(find.byType(ListView).last, const Offset(0, -3000));
      await t.pump(const Duration(seconds: 1));
    };

void main() {
  testWidgets('address sheet', (t) => shot(
        t,
        'checkout_sheet',
        const Scaffold(),
        overrides: _base(),
        before: (t) async {
          await _push(const CheckoutScreen(), checkoutScreenRoute)(t);
          await t.tap(find.text('Change'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
        },
      ),);

  setUpAll(loadShotFonts);

  for (final dark in [false, true]) {
    testWidgets('cart tab dark=$dark', (t) => shot(
          t,
          'cart_tab',
          const EntryPoint(),
          dark: dark,
          overrides: [..._base(), entryTabIndexProvider.overrideWith((_) => 2)],
          before: _precache,
        ),);
    testWidgets('cart standalone dark=$dark', (t) => shot(
          t,
          'cart_pushed',
          const Scaffold(),
          dark: dark,
          overrides: _base(short: true),
          before: _push(const CartScreen(), cartScreenRoute),
        ),);
    testWidgets('checkout dark=$dark', (t) => shot(
          t,
          'checkout',
          const Scaffold(),
          dark: dark,
          overrides: _base(),
          before: _push(const CheckoutScreen(), checkoutScreenRoute),
        ),);
    testWidgets('checkout bottom dark=$dark', (t) => shot(
          t,
          'checkout_bottom',
          const Scaffold(),
          dark: dark,
          overrides: _base(),
          before: _thenScroll(
            _push(const CheckoutScreen(), checkoutScreenRoute),
          ),
        ),);
    testWidgets('thanks bottom dark=$dark', (t) => shot(
          t,
          'thanks_bottom',
          ThanksForOrderScreen(order: _order),
          dark: dark,
          overrides: _base(),
          before: _thenScroll(_precache),
        ),);
    testWidgets('order detail bottom dark=$dark', (t) => shot(
          t,
          'order_detail_bottom',
          const Scaffold(),
          dark: dark,
          overrides: _base(),
          before: _thenScroll(
            _push(
              const OrderDetailScreen(orderId: 'o1'),
              orderDetailsScreenRoute,
            ),
          ),
        ),);
    testWidgets('processing dark=$dark', (t) => shot(
          t,
          'processing',
          const OrderProcessingScreen(
            args: OrderProcessingArgs(
              orderId: 'o1',
              providerPaymentId: 'pay_1',
              signature: 'sig',
            ),
          ),
          dark: dark,
          overrides: _base(),
        ),);
    testWidgets('thanks dark=$dark', (t) => shot(
          t,
          'thanks',
          ThanksForOrderScreen(order: _order),
          dark: dark,
          overrides: _base(),
          before: _precache,
        ),);
    testWidgets('orders tab dark=$dark', (t) => shot(
          t,
          'orders_tab',
          const EntryPoint(),
          dark: dark,
          overrides: [..._base(), entryTabIndexProvider.overrideWith((_) => 3)],
        ),);
    testWidgets('order detail dark=$dark', (t) => shot(
          t,
          'order_detail',
          const Scaffold(),
          dark: dark,
          overrides: _base(),
          before: _push(
            const OrderDetailScreen(orderId: 'o1'),
            orderDetailsScreenRoute,
          ),
        ),);
  }
}
