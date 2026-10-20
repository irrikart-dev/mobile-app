import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_envelope.dart';
import '../../models/cart_state.dart';
import '../ui/ui.dart';

/// Adds [variantId] to the cart. A cart holds one seller's items only; on
/// that `409` (it carries `details.currentVendorId`, unlike the stock one)
/// this offers to clear the cart and add. Returns false if the user said no.
/// Every other error is rethrown.
Future<bool> addToCart(
  BuildContext context,
  WidgetRef ref,
  String variantId, {
  int quantity = 1,
}) async {
  final cart = ref.read(cartControllerProvider.notifier);
  try {
    await cart.add(variantId, quantity: quantity);
    return true;
  } on ApiException catch (e) {
    if (!e.isConflict || e.details?['currentVendorId'] == null) rethrow;
    if (!context.mounted) return false;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Start a new cart?',
      message: e.message,
      confirmLabel: 'Clear cart and add',
      icon: Icons.remove_shopping_cart_rounded,
    );
    if (!confirmed) return false;
    await cart.clear();
    await cart.add(variantId, quantity: quantity);
    return true;
  }
}
