import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cart_state.dart';
import '../../../route/route_constants.dart';

enum _PaymentMethod { cod, upi, card }

extension on _PaymentMethod {
  String get label => switch (this) {
        _PaymentMethod.cod => 'Cash on Delivery',
        _PaymentMethod.upi => 'UPI',
        _PaymentMethod.card => 'Credit / Debit Card',
      };

  IconData get icon => switch (this) {
        _PaymentMethod.cod => Icons.payments_outlined,
        _PaymentMethod.upi => Icons.qr_code,
        _PaymentMethod.card => Icons.credit_card,
      };
}

/// Single-page checkout: delivery address, order items, payment method,
/// price breakup, place order. Matches the reference theme's IA - payment
/// method is chosen inline here, not on a separate route.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  _PaymentMethod _method = _PaymentMethod.cod;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider.notifier);
    final lines = ref.watch(cartControllerProvider);
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          140,
        ),
        children: [
          _Section(
            title: 'Delivery Address',
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: ext.divider),
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Add a delivery address to continue.\nAddress book is coming soon.',
                    ),
                  ),
                ],
              ),
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
                          child: Image.asset(
                            line.product.image,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            line.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('× ${line.qty}'),
                        const SizedBox(width: AppSpacing.sm),
                        Text(formatInr(line.lineTotal)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Payment Method',
            child: Column(
              children: [
                for (final method in _PaymentMethod.values)
                  _PaymentMethodTile(
                    method: method,
                    isSelected: method == _method,
                    onTap: () => setState(() => _method = method),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Order Summary',
            child: Column(
              children: [
                _SummaryRow('Subtotal', formatInr(cart.subtotal)),
                if (cart.savings > 0)
                  _SummaryRow(
                    'Discount',
                    '-${formatInr(cart.savings)}',
                    valueColor: ext.discount,
                  ),
                _SummaryRow(
                  'Delivery Fee',
                  cart.deliveryFee_ == 0
                      ? 'FREE'
                      : formatInr(cart.deliveryFee_),
                  valueColor: cart.deliveryFee_ == 0 ? ext.success : null,
                ),
                const Divider(height: AppSpacing.lg),
                _SummaryRow('Total', formatInr(cart.grandTotal), isTotal: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ElevatedButton(
            onPressed: lines.isEmpty
                ? null
                : () {
                    cart.clear();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      thanksForOrderScreenRoute,
                      (route) => false,
                    );
                  },
            child: Text('Place Order · ${formatInr(cart.grandTotal)}'),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final _PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : ext.divider,
            width: isSelected ? 1.4 : 1,
          ),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(method.icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(method.label)),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? theme.colorScheme.primary : ext.muted,
            ),
          ],
        ),
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
  const _SummaryRow(
    this.label,
    this.value, {
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;

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
          Text(value, style: style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
