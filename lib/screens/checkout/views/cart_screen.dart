import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/product/catalog_grid_skeleton.dart';
import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../entry_point_tab.dart';
import '../../../models/cart_state.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';

/// Shell tab index of the cart (see `EntryPoint._pages`).
const _cartTab = 2;

/// Cart. A tab root inside the shell, and also pushable via
/// `cartScreenRoute` — [AppTopBar] adds a back button only in that case.
///
/// Works signed out too (a device-only guest cart, see [CartController]);
/// only checkout needs an account. After sign-in merges the guest cart, any
/// lines the server refused are explained once in a bottom sheet.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _skippedSheetScheduled = false;

  /// True when pushed on its own route rather than shown as a shell tab —
  /// decides whether the checkout bar has to clear the floating nav.
  static bool _isStandalone(BuildContext context) {
    final route = ModalRoute.of(context);
    final name = route?.settings.name;
    if (name == cartScreenRoute) return true;
    return (route?.canPop ?? false) && name != entryPointScreenRoute;
  }

  /// Shows the merge's skipped lines once — only while this cart is what
  /// the user is actually looking at (the shell keeps every tab built
  /// offstage, and a pushed cart can sit over the shell's own).
  void _maybeShowSkipped(List<CartMergeSkip> skipped, bool standalone) {
    if (skipped.isEmpty || _skippedSheetScheduled) return;
    final visible = (ModalRoute.of(context)?.isCurrent ?? true) &&
        (standalone || ref.read(entryTabIndexProvider) == _cartTab);
    if (!visible) return;
    _skippedSheetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(cartMergeSkippedProvider.notifier).state = const [];
      await showAppSheet<void>(
        context,
        title: skipped.length == 1
            ? 'An item wasn’t added'
            : '${skipped.length} items weren’t added',
        builder: (_) => _MergeSkippedSheet(skipped: skipped),
      );
      _skippedSheetScheduled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartControllerProvider);
    final count = cartAsync.valueOrNull?.itemCount ?? 0;
    final standalone = _isStandalone(context);
    // Watched so switching to the cart tab re-checks for skipped lines.
    ref.watch(entryTabIndexProvider);
    _maybeShowSkipped(ref.watch(cartMergeSkippedProvider), standalone);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppTopBar(
        large: true,
        title: 'Cart',
        subtitle: count > 0 ? itemCountLabel(count) : null,
      ),
      // A plain Column, deliberately not Scaffold's bottomNavigationBar slot:
      // CartScreen lives in entry_point.dart's IndexedStack, which keeps
      // every tab's tree alive and rebuilding while offstage. A bottom bar
      // that is just another child in the body's layout avoids the special
      // measurement path Scaffold uses for its bottom slot.
      body: Column(
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
          _CartBottomBar(standalone: standalone),
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: c.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xs,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        children: [
          for (var i = 0; i < cart.items.length; i++) ...[
            if (i > 0) const Hairline(),
            _CartLineRow(
              key: ValueKey(cart.items[i].id),
              line: cart.items[i],
              onQtyChanged: (q) =>
                  _updateQty(snackContext, ref, cart.items[i], q),
              onRemove: () => _remove(snackContext, ref, cart.items[i]),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.mdPlus,
              AppSpacing.md,
              AppSpacing.mdPlus,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                SummaryRow(
                  label: 'Subtotal · ${itemCountLabel(cart.itemCount)}',
                  value: formatInr(cart.subtotal),
                ),
                SummaryRow(
                  label: 'Delivery',
                  value: 'Free',
                  valueColor: c.success,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: c.border),
                ),
                SummaryRow(
                  label: 'Total',
                  value: formatInr(cart.total),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: AppIconSize.xs,
                color: c.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Prepaid · UPI, cards & netbanking via Razorpay',
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

/// One cart line: sage product tile, name, unit price, line total and a
/// compact stepper — no card frame, rows are split by hairlines.
class _CartLineRow extends StatelessWidget {
  const _CartLineRow({
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

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        productDetailsScreenRoute,
        arguments: line.slug,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductTile(image: line.image),
            const SizedBox(width: AppSpacing.smd + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The remove button floats over the title's top-right
                  // corner so its tap target never pushes the text rows
                  // apart (one- and two-line names keep the same rhythm).
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xl),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            line.name,
                            style: context.text.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -AppSpacing.sm + 1,
                        right: -AppSpacing.sm,
                        child: AppIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Remove',
                          size: 32,
                          iconSize: AppIconSize.sm,
                          color: c.textMuted,
                          onPressed: onRemove,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${formatInr(line.price)} ${formatUnit(line.unit)}',
                    style: context.text.captionMuted,
                  ),
                  if (short) ...[
                    const SizedBox(height: AppSpacing.sm),
                    StatusPill(
                      tone: line.available <= 0 ? Tone.error : Tone.warning,
                      dot: true,
                      label: line.available <= 0
                          ? 'Out of stock'
                          : 'Only ${line.available} left',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.smd),
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
  const _CartBottomBar({required this.standalone});

  /// Pushed on its own route — otherwise the bar sits above the shell's
  /// floating nav.
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider).valueOrNull ?? Cart.empty;
    if (cart.isEmpty) return const SizedBox.shrink();

    final c = context.colors;
    final signedIn = ref.watch(isSignedInProvider);
    final short = cart.items.any((l) => l.quantity > l.available);
    // Inside the shell, Scaffold.extendBody already folds the floating nav
    // into MediaQuery.padding (and the system inset may be consumed from
    // viewPadding), so take whichever is larger — the bar clears the nav
    // either way.
    final padded = MediaQuery.paddingOf(context).bottom;
    final bottom = standalone
        ? padded
        : math.max(
            padded,
            AppSpacing.navBarHeight +
                AppSpacing.navFloatGap +
                MediaQuery.viewPaddingOf(context).bottom,
          );

    // RepaintBoundary keeps this bar's paint scoped to its own layer — the
    // tab shell's IndexedStack rebuilds it while offstage (see body note).
    return RepaintBoundary(
      child: StickyFooter(
        bottom: bottom,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (short) ...[
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: AppIconSize.xs + 2,
                    color: c.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      'Update the items marked above to continue',
                      style: context.text.caption.copyWith(color: c.warning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smd),
            ] else if (!signedIn) ...[
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: AppIconSize.xs + 2,
                    color: c.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      'Sign in to check out — your cart stays as it is.',
                      style: context.text.captionMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smd),
            ],
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: context.text.captionMuted),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(formatInr(cart.total), style: context.text.h2),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: AppButton(
                    label: 'Checkout',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: short
                        ? null
                        : () => Navigator.pushNamed(
                              context,
                              // The guest cart is kept and merged into the
                              // account on sign-in.
                              signedIn ? checkoutScreenRoute : logInScreenRoute,
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lines `POST /cart/merge` couldn't add after sign-in, each with the
/// server's own reason.
class _MergeSkippedSheet extends StatelessWidget {
  const _MergeSkippedSheet({required this.skipped});

  final List<CartMergeSkip> skipped;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your cart moved to your account, but '
          '${skipped.length == 1 ? 'this item' : 'these items'} '
          'couldn’t come along:',
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < skipped.length; i++) ...[
          if (i > 0) const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductTile(image: skipped[i].image, size: 52),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skipped[i].name ?? 'An item',
                        style: context.text.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Qty ${skipped[i].quantity} · ${skipped[i].reason}',
                        style: context.text.captionMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Got it',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
