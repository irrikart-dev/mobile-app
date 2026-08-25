import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Orders',
      icon: Icons.receipt_long_outlined,
      title: 'Your orders',
      message:
          'Order history, live status from dispatch to delivery, invoices and '
          'reorder are on the way.',
    );
  }
}
