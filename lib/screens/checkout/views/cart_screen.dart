import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cart_state.dart';
import '../../../route/route_constants.dart';

/// Cart tab. Matches the reference theme's `cart-screen`: line items with a
/// quantity stepper, a coupon field, a totals summary, and a sticky
/// checkout bar.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart (${lines.length})'),
        automaticallyImplyLeading: false,
      ),
      body: lines.isEmpty
          ? const _EmptyCart()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                160,
              ),
              children: [
                for (final line in lines)
                  _CartLineTile(
                    line: line,
                    onQtyChanged: (q) => ref
                        .read(cartControllerProvider.notifier)
                        .setQty(line.product.slug, q),
                    onRemove: () => ref
                        .read(cartControllerProvider.notifier)
                        .remove(line.product.slug),
                  ),
                const SizedBox(height: AppSpacing.md),
                const _CouponField(),
              ],
            ),
      bottomNavigationBar: lines.isEmpty ? null : const _CartSummaryBar(),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Your cart is empty', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add drip kits, sprinklers or filters to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onQtyChanged,
    required this.onRemove,
  });

  final CartLine line;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;
    final product = line.product;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: ext.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: Image.asset(
              product.image,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product.tagline,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      formatInr(line.lineTotal),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    _QtyStepper(qty: line.qty, onChanged: onQtyChanged),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove, onTap: () => onChanged(qty - 1)),
          SizedBox(
            width: 20,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          _StepButton(icon: Icons.add, onTap: () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 14),
      ),
    );
  }
}

class _CouponField extends StatefulWidget {
  const _CouponField();

  @override
  State<_CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<_CouponField> {
  final _controller = TextEditingController();
  String? _applied;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorsExt>()!;

    if (_applied != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: ext.success.withValues(alpha: 0.1),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer, size: 18, color: ext.success),
            const SizedBox(width: 8),
            Expanded(child: Text("'$_applied' applied")),
            TextButton(
              onPressed: () => setState(() => _applied = null),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Enter coupon code (try IRRI10)',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().toUpperCase() == 'IRRI10') {
              setState(() => _applied = 'IRRI10');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid coupon code')),
              );
            }
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _CartSummaryBar extends ConsumerWidget {
  const _CartSummaryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider.notifier);
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cart.deliveryFee_ == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, size: 14, color: ext.success),
                    const SizedBox(width: 4),
                    Text(
                      'You qualify for free delivery',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ext.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatInr(cart.grandTotal),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        cart.savings > 0
                            ? 'You save ${formatInr(cart.savings)}'
                            : 'Total amount',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, checkoutScreenRoute),
                  child: const Text('Checkout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
