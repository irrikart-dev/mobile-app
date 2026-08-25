import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class OnSaleScreen extends StatelessWidget {
  const OnSaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Deals',
      icon: Icons.local_offer_outlined,
      title: 'Deals on farm inputs',
      message:
          'Discounted tools, seeds and fertilizer will be listed here once '
          'pricing and offers are connected.',
    );
  }
}
