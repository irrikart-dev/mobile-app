/// One step in an order's tracking timeline.
class OrderTrackingStep {
  const OrderTrackingStep({required this.label, required this.done, this.date});

  final String label;
  final bool done;
  final String? date;
}

enum OrderStatus { processing, packed, shipped, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.processing => 'Processing',
        OrderStatus.packed => 'Packed',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };
}

class OrderLineItem {
  const OrderLineItem({
    required this.productSlug,
    required this.qty,
    required this.price,
  });

  final String productSlug;
  final int qty;
  final int price;

  int get lineTotal => qty * price;
}

/// A placed order. Mock data standing in for `features/orders`, adapted
/// from the reference theme's own sample orders.
class MockOrder {
  const MockOrder({
    required this.id,
    required this.date,
    required this.status,
    required this.items,
    this.eta,
    required this.trackingSteps,
  });

  final String id;
  final String date;
  final OrderStatus status;
  final List<OrderLineItem> items;
  final String? eta;
  final List<OrderTrackingStep> trackingSteps;

  int get total => items.fold(0, (sum, i) => sum + i.lineTotal);
}

const List<MockOrder> mockOrders = [
  MockOrder(
    id: 'IRW-108422',
    date: '12 Mar 2026',
    status: OrderStatus.delivered,
    items: [
      OrderLineItem(productSlug: 'rps-select', qty: 2, price: 1249),
      OrderLineItem(productSlug: 't-type-disc-filter', qty: 1, price: 1099),
    ],
    trackingSteps: [
      OrderTrackingStep(label: 'Order Placed', done: true, date: '12 Mar'),
      OrderTrackingStep(label: 'Packed', done: true, date: '13 Mar'),
      OrderTrackingStep(label: 'Shipped', done: true, date: '14 Mar'),
      OrderTrackingStep(label: 'Delivered', done: true, date: '17 Mar'),
    ],
  ),
  MockOrder(
    id: 'IRW-108790',
    date: '2 Apr 2026',
    status: OrderStatus.shipped,
    items: [
      OrderLineItem(productSlug: 'winkit-jeet-kisaan-ki', qty: 1, price: 4499),
    ],
    eta: 'Arriving 8 Apr',
    trackingSteps: [
      OrderTrackingStep(label: 'Order Placed', done: true, date: '2 Apr'),
      OrderTrackingStep(label: 'Packed', done: true, date: '3 Apr'),
      OrderTrackingStep(label: 'Shipped', done: true, date: '4 Apr'),
      OrderTrackingStep(label: 'Delivered', done: false),
    ],
  ),
  MockOrder(
    id: 'IRW-109011',
    date: '18 Apr 2026',
    status: OrderStatus.processing,
    items: [
      OrderLineItem(productSlug: 'hanging-fogger', qty: 4, price: 89),
      OrderLineItem(
        productSlug: 'mini-digital-tap-water-timer',
        qty: 1,
        price: 899,
      ),
    ],
    eta: 'Arriving 25 Apr',
    trackingSteps: [
      OrderTrackingStep(label: 'Order Placed', done: true, date: '18 Apr'),
      OrderTrackingStep(label: 'Packed', done: false),
      OrderTrackingStep(label: 'Shipped', done: false),
      OrderTrackingStep(label: 'Delivered', done: false),
    ],
  ),
];
