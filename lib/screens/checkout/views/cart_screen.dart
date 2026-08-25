import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Hosted inside the tab shell, so no Scaffold or AppBar here.
    return const ComingSoonView(
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart',
      message:
          'Adding items, quantity by pack unit, and the full price breakup are '
          'being built. You will be able to check out from here soon.',
    );
  }
}
