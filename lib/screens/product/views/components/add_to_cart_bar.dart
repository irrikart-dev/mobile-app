import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/cart_state.dart';
import '../../../../models/catalog_data.dart';
import '../../../../models/catalog_product.dart';
import '../../../../route/route_constants.dart';

/// Sticky PDP footer: quantity stepper + a pill "Add to cart · ₹total".
///
/// "Add to cart" re-fetches the product live first (contract rule — price
/// and stock are what's most likely to have moved since the screen loaded).
/// Once added, the button becomes "Go to cart" until the option or quantity
/// changes.
class AddToCartBar extends ConsumerStatefulWidget {
  const AddToCartBar({
    super.key,
    required this.product,
    required this.variant,
    required this.qty,
    required this.maxQty,
    required this.onQtyChanged,
    required this.onGoToCart,
  });

  final CatalogProduct product;
  final CatalogVariant variant;
  final int qty;

  /// Upper bound for the stepper — what can actually be bought.
  final int maxQty;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onGoToCart;

  @override
  ConsumerState<AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends ConsumerState<AddToCartBar> {
  bool _busy = false;
  bool _added = false;

  @override
  void didUpdateWidget(covariant AddToCartBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant.id != widget.variant.id ||
        oldWidget.qty != widget.qty ||
        oldWidget.product.id != widget.product.id) {
      _added = false;
    }
  }

  Future<void> _addToCart() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Contract rule: re-read the product live immediately before adding to
      // cart — price and stock are what's most likely to have moved since
      // this screen loaded.
      final fresh = await CatalogData.fetchFreshProduct(
        ref.read(dioProvider),
        widget.product.id,
      );
      final freshVariant = fresh.variants.firstWhere(
        (v) => v.id == widget.variant.id,
        orElse: () => CatalogVariant(
          id: fresh.variantId,
          sku: fresh.sku,
          size: null,
          color: null,
          unit: fresh.unit,
          price: fresh.price,
          stockQty: fresh.stockQty,
          available: fresh.stockQty,
        ),
      );
      if (!freshVariant.buyable) {
        if (mounted) {
          AppSnack.show(
            context,
            'This option just went out of stock.',
            tone: Tone.warning,
          );
        }
        return;
      }

      await ref
          .read(cartControllerProvider.notifier)
          .add(freshVariant.id, quantity: widget.qty);

      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _added = true);
      AppSnack.show(
        context,
        'Added ${fresh.name} to cart',
        tone: Tone.success,
        actionLabel: 'View cart',
        onAction: widget.onGoToCart,
      );
    } on AuthRequiredException {
      if (!mounted) return;
      unawaited(
        Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (route) => false,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : 'Could not add this to your cart.';
      AppSnack.error(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final variant = widget.variant;
    final buyable = variant.buyable;
    final total = formatInr(variant.price * widget.qty);

    final Widget action = !buyable
        ? const AppButton(
            key: ValueKey('oos'),
            label: 'Out of stock',
            onPressed: null,
          )
        : _added
            ? AppButton(
                key: const ValueKey('go'),
                label: 'Go to cart',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: widget.onGoToCart,
              )
            : AppButton(
                key: const ValueKey('add'),
                label: 'Add to cart · $total',
                loading: _busy,
                onPressed: _addToCart,
              );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        boxShadow: c.shadowRaised,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.smd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mdPlus,
            AppSpacing.smd,
            AppSpacing.mdPlus,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              if (buyable) ...[
                // The stepper is a 40pt sage pill; seat it in a sage pill as
                // tall as the CTA so the two read as one matched row.
                Container(
                  height: AppButtonSize.lg.height,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs + 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: AppRadius.pillAll,
                  ),
                  alignment: Alignment.center,
                  child: QuantityStepper(
                    value: widget.qty,
                    max: widget.maxQty,
                    busy: _busy,
                    onChanged: widget.onQtyChanged,
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: action,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
