import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/component_themes/button_styles.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/address_data.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../address/views/addresses_screen.dart';
import 'order_processing_screen.dart';

/// Single-page checkout: delivery address, order items, coupon, price
/// breakup, pay. Payment method itself (UPI/card/wallet) is chosen inside
/// the Razorpay widget, not here — there is no COD; the checkout contract
/// only ever returns a Razorpay order.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _couponController = TextEditingController();
  String? _appliedCoupon;
  bool _paying = false;
  String? _error;
  Address? _selectedAddress;
  bool _addressInitialized = false;

  @override
  void initState() {
    super.initState();
    // Contract rule: always re-read the cart immediately before checkout —
    // the totals charged must be current, not whatever was last cached.
    unawaited(
      Future.microtask(
        () => ref.read(cartControllerProvider.notifier).refresh(),
      ),
    );
  }

  void _pickAddress() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => AddressesScreen(
          onPicked: (address) {
            setState(() => _selectedAddress = address);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_paying) return;
    final address = _selectedAddress;
    if (address == null) {
      setState(() => _error = 'Choose a delivery address to continue.');
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });

    try {
      // Has side effects even before payment — re-validates stock/price live
      // and reserves stock — which is exactly why this only runs on the
      // explicit tap, never speculatively.
      final checkoutOrder = await ref.read(ordersRepositoryProvider).checkout(
            addressId: address.id,
            couponCode: _appliedCoupon,
          );

      final result = await openRazorpayCheckout(
        keyId: checkoutOrder.keyId,
        providerOrderId: checkoutOrder.providerOrderId,
        amountRupees: checkoutOrder.amount,
        currency: checkoutOrder.currency,
      );

      if (!mounted) return;

      switch (result.outcome) {
        case RazorpayOutcome.failure:
          // The order this checkout call created resolves to CANCELLED on
          // its own via the webhook; the cart is untouched, so staying here
          // and letting the user retry is safe.
          setState(() => _error = result.message);
        case RazorpayOutcome.success:
        case RazorpayOutcome.externalWallet:
          // Neither means the order is actually confirmed yet — the
          // processing screen verifies it immediately (falling back to
          // polling for the external-wallet case, which has no payment id
          // yet), per the checkout contract §4.
          unawaited(
            Navigator.pushReplacementNamed(
              context,
              orderProcessingScreenRoute,
              arguments: OrderProcessingArgs(
                orderId: checkoutOrder.orderId,
                providerPaymentId: result.paymentId,
                signature: result.signature,
              ),
            ),
          );
      }
    } catch (e) {
      if (mounted) setState(() => _error = orderErrorMessage(e));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartControllerProvider);
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    // Default to the caller's default address the first time the list
    // loads — after that, whatever they picked (including "none yet") wins.
    ref.listen(addressControllerProvider, (previous, next) {
      if (_addressInitialized) return;
      final addresses = next.valueOrNull;
      if (addresses == null) return;
      _addressInitialized = true;
      if (addresses.isEmpty) return;
      final defaults = addresses.where((a) => a.isDefault);
      final defaultAddress = defaults.isNotEmpty ? defaults.first : addresses.first;
      setState(() => _selectedAddress = defaultAddress);
    });
    ref.watch(addressControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(cartErrorMessage(err), textAlign: TextAlign.center),
          ),
        ),
        data: (cart) {
          final lines = cart.items;
          final short = lines.any((l) => l.available < l.quantity);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              140,
            ),
            children: [
              _Section(
                title: 'Delivery Address',
                child: InkWell(
                  onTap: _pickAddress,
                  borderRadius: AppRadius.mdAll,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedAddress == null
                            ? ext.warning
                            : ext.divider,
                      ),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _selectedAddress == null
                              ? const Text('Choose a delivery address')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedAddress!.name,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(_selectedAddress!.oneLine),
                                  ],
                                ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              if (short)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: ext.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: ext.warning,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Some items in your cart have less stock than you '
                          'requested. Update quantities before paying.',
                        ),
                      ),
                    ],
                  ),
                ),
              _Section(
                title: 'Order Items (${lines.length})',
                child: Column(
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.smAll,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: CatalogImage(
                                  source: line.image,
                                  isRemote: line.hasRemoteImage,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                line.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('× ${line.quantity}'),
                            const SizedBox(width: AppSpacing.sm),
                            Text(formatInr(line.lineTotal)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'Coupon',
                child: _appliedCoupon != null
                    ? Container(
                        padding: const EdgeInsets.all(AppSpacing.smd),
                        decoration: BoxDecoration(
                          color: ext.success.withValues(alpha: 0.1),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 18,
                              color: ext.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text("'$_appliedCoupon' applied")),
                            TextButton(
                              onPressed: _paying
                                  ? null
                                  : () => setState(() => _appliedCoupon = null),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponController,
                              enabled: !_paying,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Enter coupon code',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 120,
                            child: ElevatedButton(
                              // In a Row — see AppButtonStyles.inline.
                              style: AppButtonStyles.inline,
                              onPressed: _paying
                                  ? null
                                  : () {
                                      final code = _couponController.text.trim();
                                      if (code.isEmpty) return;

                                      setState(() => _appliedCoupon = code);
                                    },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
              ),
              _Section(
                title: 'Order Summary',
                child: Column(
                  children: [
                    _SummaryRow('Subtotal', formatInr(cart.subtotal)),
                    const Divider(height: AppSpacing.lg),
                    _SummaryRow('Total', formatInr(cart.total), isTotal: true),
                    Text(
                      'Coupon discounts, if any, are applied when you pay.',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: ext.muted),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _ErrorBanner(_error!),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ElevatedButton(
            onPressed: switch (cartAsync) {
              AsyncData(value: final cart)
                  when cart.items.isNotEmpty && !_paying =>
                _pay,
              _ => null,
            },
            child: Text(
              _paying
                  ? 'Opening payment…'
                  : switch (cartAsync) {
                      AsyncData(value: final cart) =>
                        'Pay · ${formatInr(cart.total)}',
                      _ => 'Pay',
                    },
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        isTotal ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
