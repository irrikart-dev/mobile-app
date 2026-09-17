import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/component_themes/button_styles.dart';
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
    final cartAsync = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart (${cartAsync.valueOrNull?.items.length ?? 0})'),
        automaticallyImplyLeading: false,
      ),
      // A plain Column, deliberately not Scaffold's bottomNavigationBar slot.
      // CartScreen lives inside entry_point.dart's IndexedStack, which keeps
      // every tab's Element tree alive — and rebuilding on provider changes
      // — even while offstage and unpainted. Scaffold's bottomNavigationBar
      // has its own transition/measurement machinery that assumes normal
      // paint visibility; a shadow-painting box rebuilt there while offstage
      // hit "RenderBox was not laid out — hasSize" (its shadow paint pass
      // needs `size` before this subtree has had a layout pass). A bottom
      // bar that is just another child in the body's layout has no such
      // special-cased code path to collide with.
      body: Column(
        children: [
          Expanded(
            child: cartAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => _CartError(error: err),
              data: (cart) => cart.isEmpty
                  ? const _EmptyCart()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      children: [
                        // Coupon entry lives on the checkout screen, where the
                        // code is actually sent to /orders/checkout — there is
                        // nothing here that could apply one.
                        for (final line in cart.items)
                          _CartLineTile(
                            line: line,
                            onQtyChanged: (q) =>
                                _updateQty(context, ref, line, q),
                            onRemove: () => _remove(context, ref, line),
                          ),
                      ],
                    ),
            ),
          ),
          const _CartSummaryBar(),
        ],
      ),
    );
  }

  Future<void> _updateQty(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
    int quantity,
  ) async {
    try {
      if (quantity <= 0) {
        await ref.read(cartControllerProvider.notifier).remove(line.id);
      } else {
        await ref
            .read(cartControllerProvider.notifier)
            .setQuantity(line.id, quantity);
      }
    } catch (e) {
      if (context.mounted) _showCartError(context, e);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    try {
      await ref.read(cartControllerProvider.notifier).remove(line.id);
    } catch (e) {
      if (context.mounted) _showCartError(context, e);
    }
  }
}

void _showCartError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(cartErrorMessage(error))),
  );
}

class _CartError extends ConsumerWidget {
  const _CartError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error is AuthRequiredException) {
      return _SignInRequiredNotice(
        onSignIn: () => Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (route) => false,
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cartErrorMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () =>
                  ref.read(cartControllerProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInRequiredNotice extends StatelessWidget {
  const _SignInRequiredNotice({required this.onSignIn});

  final VoidCallback onSignIn;

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
              Icons.lock_outline,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Sign in to see your cart', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your session has expired. Sign in again to pick up where you left off.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onSignIn, child: const Text('Sign in')),
          ],
        ),
      ),
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
    final short = line.available < line.quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: short ? ext.warning : ext.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: CatalogImage(
                    source: line.image,
                    isRemote: line.hasRemoteImage,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
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
                        _QtyStepper(
                          qty: line.quantity,
                          onChanged: onQtyChanged,
                        ),
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
          if (short) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              line.available <= 0
                  ? 'Out of stock — remove or wait for restock'
                  : 'Only ${line.available} left — you have ${line.quantity} in cart',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ext.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

class _CartSummaryBar extends ConsumerWidget {
  const _CartSummaryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider).valueOrNull ?? Cart.empty;
    if (cart.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // RepaintBoundary matters here, not decorative: CartScreen sits inside
    // entry_point.dart's IndexedStack, which keeps every tab's Element tree
    // alive (and rebuilding on provider changes) even while offstage and
    // unpainted. A shadow-painting RenderDecoratedBox rebuilt in that state
    // hits Flutter's "RenderBox was not laid out — hasSize" assertion — its
    // shadow paint pass needs `size` before this subtree's had a layout
    // pass. Giving it its own compositing layer keeps that paint attempt
    // scoped to a boundary that's actually been laid out.
    return RepaintBoundary(
      child: SafeArea(
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatInr(cart.total),
                      style: theme.textTheme.titleLarge,
                    ),
                    Text('Total amount', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              ElevatedButton(
                // In a Row — see AppButtonStyles.inline for why this is not
                // optional.
                style: AppButtonStyles.inline,
                onPressed: () =>
                    Navigator.pushNamed(context, checkoutScreenRoute),
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
