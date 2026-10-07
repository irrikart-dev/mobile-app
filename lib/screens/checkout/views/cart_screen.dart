import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cart_state.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';

/// Cart. A tab root inside the shell, and also pushable via
/// `cartScreenRoute` — [AppTopBar] adds a back button only in that case.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final cartAsync = ref.watch(cartControllerProvider);
    final count = cartAsync.valueOrNull?.itemCount ?? 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppTopBar(
        large: true,
        title: 'Cart',
        subtitle: signedIn && count > 0
            ? '$count ${count == 1 ? 'item' : 'items'}'
            : null,
      ),
      // A plain Column, deliberately not Scaffold's bottomNavigationBar slot:
      // CartScreen lives in entry_point.dart's IndexedStack, which keeps
      // every tab's tree alive and rebuilding while offstage. A bottom bar
      // that is just another child in the body's layout avoids the special
      // measurement path Scaffold uses for its bottom slot.
      body: !signedIn
          ? EmptyState(
              icon: Icons.lock_rounded,
              title: 'Sign in to see your cart',
              message:
                  'Your cart is saved to your account so it follows you across devices.',
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, logInScreenRoute),
            )
          : Column(
              children: [
                Expanded(
                  child: cartAsync.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const CartLinesSkeleton(),
                    error: (err, _) => _CartError(error: err),
                    data: (cart) => cart.isEmpty
                        ? RefreshableFill(
                            onRefresh: () => _pullRefresh(ref),
                            child: EmptyState(
                              icon: Icons.shopping_bag_rounded,
                              title: 'Your cart is empty',
                              message:
                                  'Add drip kits, sprinklers, pumps or filters to get started.',
                              actionLabel: 'Start shopping',
                              onAction: () => goToShellTab(context, ref, 0),
                            ),
                          )
                        : _CartList(
                            cart: cart,
                            snackContext: context,
                            onRefresh: () => _pullRefresh(ref),
                          ),
                  ),
                ),
                const _CartBottomBar(),
              ],
            ),
    );
  }

  // Invalidate (not `refresh()`) so the current lines stay on screen under
  // the pull-to-refresh spinner instead of flashing to a skeleton.
  Future<void> _pullRefresh(WidgetRef ref) async {
    try {
      ref.invalidate(cartControllerProvider);
      await ref.read(cartControllerProvider.future);
    } catch (_) {
      // Surfaced by the error branch of `when`.
    }
  }
}

class _CartList extends ConsumerWidget {
  const _CartList({
    required this.cart,
    required this.onRefresh,
    required this.snackContext,
  });

  final Cart cart;

  /// The screen's own context — outlives this list, which unmounts the
  /// moment the last line is removed (and the Undo snack still needs one).
  final BuildContext snackContext;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final short = cart.items.any((l) => l.quantity > l.available);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: c.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        children: [
          if (short) ...[
            const InlineBanner(
              tone: Tone.warning,
              title: 'Some items are short on stock',
              message:
                  'Reduce the quantity or remove the items marked below to continue to checkout.',
            ),
            const SizedBox(height: AppSpacing.smd),
          ],
          for (final line in cart.items) ...[
            _CartLineCard(
              key: ValueKey(line.id),
              line: line,
              onQtyChanged: (q) => _updateQty(snackContext, ref, line, q),
              onRemove: () => _remove(snackContext, ref, line),
            ),
            const SizedBox(height: AppSpacing.smd),
          ],
          const SizedBox(height: AppSpacing.xs),
          SectionCard(
            title: 'Price details',
            icon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                SummaryRow(
                  label:
                      'Subtotal (${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'})',
                  value: formatInr(cart.subtotal),
                ),
                SummaryRow(
                  label: 'Delivery',
                  value: 'Free',
                  valueColor: c.success,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: c.divider),
                ),
                SummaryRow(
                  label: 'Total',
                  value: formatInr(cart.total),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 14, color: c.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Prepaid orders · UPI, cards & netbanking via Razorpay',
                  style: context.text.captionMuted,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
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
    if (quantity <= 0) return _remove(context, ref, line);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .setQuantity(line.id, quantity);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, cartErrorMessage(e));
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final controller = ref.read(cartControllerProvider.notifier);
    try {
      await controller.remove(line.id);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, cartErrorMessage(e));
      return;
    }
    if (!context.mounted) return;
    AppSnack.show(
      context,
      '${line.name} removed',
      actionLabel: 'Undo',
      duration: const Duration(seconds: 4),
      onAction: () async {
        try {
          await controller.add(line.variantId, quantity: line.quantity);
        } catch (e) {
          if (context.mounted) AppSnack.error(context, cartErrorMessage(e));
        }
      },
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    super.key,
    required this.line,
    required this.onQtyChanged,
    required this.onRemove,
  });

  final CartLine line;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final short = line.quantity > line.available;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.smd),
      borderColor: short ? c.warning : null,
      onTap: () => Navigator.pushNamed(
        context,
        productDetailsScreenRoute,
        arguments: line.slug,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderThumb(
                size: 72,
                child: CatalogImage(
                  source: line.image,
                  isRemote: line.hasRemoteImage,
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            line.name,
                            style: context.text.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Remove',
                          size: 32,
                          iconSize: 18,
                          color: c.textMuted,
                          onPressed: onRemove,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${formatInr(line.price)} ${formatUnit(line.unit)}',
                      style: context.text.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: PriceText(line.lineTotal)),
                        QuantityStepper(
                          value: line.quantity,
                          onChanged: onQtyChanged,
                          allowRemove: true,
                          max: line.available,
                          size: StepperSize.sm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (short) ...[
            const SizedBox(height: AppSpacing.smd),
            InlineBanner(
              tone: Tone.warning,
              message: line.available <= 0
                  ? 'Out of stock — remove it or check back after restock.'
                  : 'Only ${line.available} left — you have ${line.quantity} in your cart.',
            ),
          ],
        ],
      ),
    );
  }
}

class _CartError extends ConsumerWidget {
  const _CartError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error is AuthRequiredException) {
      return EmptyState(
        icon: Icons.lock_rounded,
        title: 'Sign in to see your cart',
        message:
            'Your session has expired. Sign in again to pick up where you left off.',
        actionLabel: 'Sign in',
        onAction: () => Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
      );
    }
    return ErrorState(
      error: error,
      message: cartErrorMessage(error),
      onRetry: () => ref.read(cartControllerProvider.notifier).refresh(),
    );
  }
}

class _CartBottomBar extends ConsumerWidget {
  const _CartBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider).valueOrNull ?? Cart.empty;
    if (cart.isEmpty) return const SizedBox.shrink();

    final c = context.colors;
    final short = cart.items.any((l) => l.quantity > l.available);

    // RepaintBoundary keeps this bar's paint scoped to its own layer — the
    // tab shell's IndexedStack rebuilds it while offstage (see body note).
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (short) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: c.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Fix stock issues above to continue',
                          style: context.text.caption.copyWith(
                            color: c.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: context.text.caption),
                        PriceText(cart.total),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Checkout',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: short
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  checkoutScreenRoute,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
