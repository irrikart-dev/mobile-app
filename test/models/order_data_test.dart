import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/payments/saved_payment_methods.dart';
import 'package:irrikart/models/order_data.dart';

OrderSummary _summary(
  OrderStatus status, {
  required DateTime createdAt,
  String? paymentMethod = 'ONLINE',
  bool accepted = false,
}) =>
    OrderSummary(
      id: 'o1',
      orderNumber: 'ORD-1',
      status: status,
      rawStatus: '',
      amount: 100,
      currency: 'INR',
      createdAt: createdAt,
      paymentMethod: paymentMethod,
      accepted: accepted,
    );

void main() {
  group('status parsing', () {
    test('maps every backend status', () {
      expect(parseOrderStatus('PLACED'), OrderStatus.placed);
      expect(parseOrderStatus('PAYMENT_FAILED'), OrderStatus.paymentFailed);
      expect(parseOrderStatus('CONFIRMED'), OrderStatus.confirmed);
      expect(parseOrderStatus('PACKED'), OrderStatus.packed);
      expect(parseOrderStatus('SHIPPED'), OrderStatus.shipped);
      expect(parseOrderStatus('DELIVERED'), OrderStatus.delivered);
      expect(parseOrderStatus('CANCELLED'), OrderStatus.cancelled);
      expect(parseOrderStatus('RETURNED'), OrderStatus.returned);
    });

    test('never crashes on an unknown or missing status', () {
      expect(parseOrderStatus('ON_HOLD'), OrderStatus.unknown);
      expect(parseOrderStatus(''), OrderStatus.unknown);
      expect(parseOrderStatus(null), OrderStatus.unknown);
    });

    test('labels match the contract table, unknown reads "Processing"', () {
      const expected = {
        OrderStatus.placed: 'Awaiting payment',
        OrderStatus.paymentFailed: 'Payment failed',
        OrderStatus.confirmed: 'Order confirmed',
        OrderStatus.packed: 'Packed',
        OrderStatus.shipped: 'Shipped',
        OrderStatus.delivered: 'Delivered',
        OrderStatus.cancelled: 'Cancelled',
        OrderStatus.returned: 'Returned',
        OrderStatus.unknown: 'Processing',
      };
      for (final s in OrderStatus.values) {
        expect(orderStatusLabel(s), expected[s], reason: s.name);
      }
      expect(orderStatusLabel(OrderStatus.unknown, 'ON_HOLD'), 'Processing');
    });

    test('only PLACED keeps the payment poll going', () {
      expect(isTerminalForPaymentPoll(OrderStatus.placed), isFalse);
      for (final s
          in OrderStatus.values.where((s) => s != OrderStatus.placed)) {
        expect(isTerminalForPaymentPoll(s), isTrue, reason: s.name);
      }
    });

    test('verify returning PAYMENT_FAILED parses', () {
      final order = Order.fromJson({
        'id': 'o1',
        'orderNumber': 'ORD-1',
        'status': 'PAYMENT_FAILED',
        'createdAt': '2026-10-07T10:00:00.000Z',
        'items': <Object>[],
      });
      expect(order.status, OrderStatus.paymentFailed);
      expect(order.awaitingPayment, isTrue);
    });
  });

  group('cancel eligibility', () {
    final placedAt = DateTime(2026, 10, 7, 10);

    test('PLACED and PAYMENT_FAILED can always be cancelled', () {
      final later = placedAt.add(const Duration(hours: 30));
      expect(
        _summary(OrderStatus.placed, createdAt: placedAt).canCancel(later),
        isTrue,
      );
      expect(
        _summary(OrderStatus.paymentFailed, createdAt: placedAt)
            .canCancel(later),
        isTrue,
      );
    });

    test('CONFIRMED only within 24 hours of placing', () {
      final o = _summary(OrderStatus.confirmed, createdAt: placedAt);
      expect(o.canCancel(placedAt.add(const Duration(hours: 23))), isTrue);
      expect(
        o.canCancel(placedAt.add(const Duration(hours: 24, minutes: 1))),
        isFalse,
      );
    });

    test('never once packed, or in a final state', () {
      for (final s in [
        OrderStatus.packed,
        OrderStatus.shipped,
        OrderStatus.delivered,
        OrderStatus.cancelled,
        OrderStatus.returned,
        OrderStatus.unknown,
      ]) {
        expect(
          _summary(s, createdAt: placedAt).canCancel(placedAt),
          isFalse,
          reason: s.name,
        );
      }
    });
  });

  group('payment window', () {
    final placedAt = DateTime(2026, 10, 7, 10);

    test('counts down 30 minutes from createdAt', () {
      final o = _summary(OrderStatus.placed, createdAt: placedAt);
      expect(o.paymentDeadline, placedAt.add(const Duration(minutes: 30)));
      expect(
        o.paymentTimeLeft(placedAt.add(const Duration(minutes: 6))),
        const Duration(minutes: 24),
      );
      expect(
        o.paymentTimeLeft(placedAt.add(const Duration(hours: 1))),
        Duration.zero,
      );
    });

    test('pay is offered only while unpaid, online and inside the window', () {
      final inWindow = placedAt.add(const Duration(minutes: 10));
      expect(
        _summary(OrderStatus.placed, createdAt: placedAt).canPay(inWindow),
        isTrue,
      );
      expect(
        _summary(OrderStatus.paymentFailed, createdAt: placedAt)
            .canPay(inWindow),
        isTrue,
      );
      expect(
        _summary(OrderStatus.placed, createdAt: placedAt)
            .canPay(placedAt.add(const Duration(minutes: 31))),
        isFalse,
      );
      expect(
        _summary(OrderStatus.confirmed, createdAt: placedAt).canPay(inWindow),
        isFalse,
      );
      expect(
        _summary(OrderStatus.placed, createdAt: placedAt, paymentMethod: 'COD')
            .canPay(inWindow),
        isFalse,
      );
    });
  });

  group('order flags', () {
    final at = DateTime(2026, 10, 7);

    test('invoice only once confirmed and not cancelled', () {
      const withInvoice = {
        OrderStatus.confirmed,
        OrderStatus.packed,
        OrderStatus.shipped,
        OrderStatus.delivered,
        OrderStatus.returned,
      };
      for (final s in OrderStatus.values) {
        expect(
          _summary(s, createdAt: at).hasInvoice,
          withInvoice.contains(s),
          reason: s.name,
        );
      }
    });

    test('seller acceptance note only for unaccepted CONFIRMED', () {
      expect(
        _summary(OrderStatus.confirmed, createdAt: at).awaitingSellerAcceptance,
        isTrue,
      );
      expect(
        _summary(OrderStatus.confirmed, createdAt: at, accepted: true)
            .awaitingSellerAcceptance,
        isFalse,
      );
      expect(
        _summary(OrderStatus.packed, createdAt: at).awaitingSellerAcceptance,
        isFalse,
      );
    });

    test('payment method labels', () {
      expect(paymentMethodLabel('ONLINE'), 'Online');
      expect(paymentMethodLabel('COD'), 'Cash on delivery');
      expect(paymentMethodLabel(null), isNull);
    });
  });

  group('parsing', () {
    test('order detail picks up payment and cancellation fields', () {
      final order = Order.fromJson({
        'id': 'o1',
        'orderNumber': 'ORD-1',
        'status': 'CANCELLED',
        'paymentMethod': 'ONLINE',
        'paymentStatus': 'CAPTURED',
        'accepted': false,
        'amount': 900,
        'subtotal': 1000,
        'discount': 100,
        'vendorAmount': 800,
        'platformAmount': 100,
        'createdAt': '2026-10-07T10:00:00.000Z',
        'cancelledAt': '2026-10-07T11:00:00.000Z',
        'cancelledBy': 'customer',
        'cancelReason': 'Ordered by mistake',
        'items': [
          {
            'id': 'oi1',
            'variantId': 'v1',
            'productId': 'p1',
            'name': 'Valve',
            'slug': 'valve',
            'image': null,
            'sku': 'V1',
            'unit': 'piece',
            'quantity': 2,
            'unitPrice': 500,
            'totalPrice': 1000,
          },
        ],
        'address': null,
        'shipment': null,
      });
      expect(order.itemsTotal, 1000);
      expect(order.discount, 100);
      expect(order.cancelReason, 'Ordered by mistake');
      expect(cancelledByLabel(order.cancelledBy), 'Cancelled by you');
      expect(order.cancelledAt, isNotNull);
      expect(order.wasPaidOnline, isTrue);
      expect(order.items.single.unit, 'piece');
    });

    test('checkout response carries customerId (nullable)', () {
      final base = {
        'orderId': 'o1',
        'orderNumber': 'ORD-1',
        'paymentMethod': 'ONLINE',
        'amount': 4500,
        'currency': 'INR',
        'providerOrderId': 'order_abc',
        'provider': 'razorpay',
        'keyId': 'rzp_test_x',
      };
      expect(
        CheckoutOrder.fromJson({...base, 'customerId': 'cust_1'}).customerId,
        'cust_1',
      );
      expect(
        CheckoutOrder.fromJson({...base, 'customerId': null}).customerId,
        isNull,
      );
    });

    test('cancel refundStatus maps to started / failed / none', () {
      expect(parseRefundStatus(null), RefundStatus.none);
      expect(parseRefundStatus('pending'), RefundStatus.started);
      expect(parseRefundStatus('processed'), RefundStatus.started);
      expect(parseRefundStatus('failed'), RefundStatus.failed);
      expect(
        cancelOutcomeMessage(RefundStatus.failed),
        contains('Your refund is being processed manually'),
      );
      expect(
        cancelOutcomeMessage(RefundStatus.started),
        contains('Refund started'),
      );
    });

    test('reorder skipped lines', () {
      final r = ReorderResult.fromJson({
        'cart': <String, Object>{},
        'skipped': [
          {'variantId': 'v1', 'quantity': 2, 'reason': 'Only 1 left'},
        ],
      });
      expect(r.skipped.single.reason, 'Only 1 left');
      expect(r.skipped.single.quantity, 2);
    });

    test('saved methods display whichever field matches the method', () {
      final card = SavedPaymentMethod.fromJson({
        'id': 't1',
        'method': 'card',
        'card': {'last4': '4242', 'network': 'Visa', 'issuer': 'HDFC'},
        'vpa': null,
        'wallet': null,
        'bank': null,
      });
      expect(card.title, 'Visa •••• 4242');
      expect(card.subtitle, 'Card · HDFC');

      final upi = SavedPaymentMethod.fromJson(
        {'id': 't2', 'method': 'upi', 'vpa': 'ravi@okhdfc'},
      );
      expect(upi.title, 'ravi@okhdfc');

      final wallet = SavedPaymentMethod.fromJson(
        {'id': 't3', 'method': 'wallet', 'wallet': 'paytm'},
      );
      expect(wallet.title, 'Paytm');

      final bank = SavedPaymentMethod.fromJson(
        {'id': 't4', 'method': 'netbanking', 'bank': 'SBIN'},
      );
      expect(bank.title, 'SBIN');
    });
  });
}
