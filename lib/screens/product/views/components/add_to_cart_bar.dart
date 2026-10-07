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

/// Sticky PDP footer: total for the chosen quantity + the primary action.
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
    required this.onGoToCart,
  });

  final CatalogProduct product;
  final CatalogVariant variant;
  final int qty;
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: c.shadowRaised,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.smd,
            AppSpacing.gutter,
            AppSpacing.smd,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyable
                          ? 'Total · ${widget.qty} ${variant.unit}'
                          : 'Price',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.captionMuted,
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: AppDurations.fast,
                      transitionBuilder: (child, a) =>
                          FadeTransition(opacity: a, child: child),
                      child: FittedBox(
                        key: ValueKey(variant.price * widget.qty),
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatInr(
                            buyable ? variant.price * widget.qty : variant.price,
                          ),
                          style: context.text.priceLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                flex: 6,
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: !buyable
                      ? const AppButton(
                          key: ValueKey('oos'),
                          label: 'Out of stock',
                          onPressed: null,
                        )
                      : _added
                          ? AppButton.secondary(
                              key: const ValueKey('go'),
                              label: 'Go to cart',
                              trailingIcon: Icons.arrow_forward_rounded,
                              onPressed: widget.onGoToCart,
                            )
                          : AppButton(
                              key: const ValueKey('add'),
                              label: 'Add to cart',
                              icon: Icons.add_shopping_cart_rounded,
                              loading: _busy,
                              onPressed: _addToCart,
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
