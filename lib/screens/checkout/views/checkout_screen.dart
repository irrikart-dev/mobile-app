import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../components/ui/ui.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/address_data.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';
import 'order_processing_screen.dart';

/// Returned by the address sheet when the user taps "Add new address".
const _addNewAddress = Object();

/// Single-page checkout: delivery address, order items, payment, coupon,
/// price summary, pay. The payment method itself (UPI/card/netbanking) is
/// chosen inside the Razorpay widget, not here — there is no COD; the
/// checkout contract only ever returns a Razorpay order.
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
  bool _itemsExpanded = false;

  /// False while `listenManual` fires its immediate callback in initState,
  /// where setState isn't appropriate.
  bool _listening = false;

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
    // Default to the user's default address once the list is known; after
    // that, whatever they picked wins (it's only replaced if it vanishes).
    ref.listenManual<AsyncValue<List<Address>>>(
      addressControllerProvider,
      (previous, next) => _syncAddress(next.valueOrNull),
      fireImmediately: true,
    );
    _listening = true;
  }

  void _syncAddress(List<Address>? addresses) {
    if (addresses == null) return;
    final current = _selectedAddress;
    if (current != null) {
      final fresh = addresses.where((a) => a.id == current.id);
      if (fresh.isNotEmpty) {
        if (!identical(fresh.first, current)) {
          _setAddress(fresh.first);
        }
        return;
      }
    }
    if (addresses.isEmpty) {
      _setAddress(null);
      return;
    }
    final defaults = addresses.where((a) => a.isDefault);
    _setAddress(defaults.isNotEmpty ? defaults.first : addresses.first);
  }

  void _setAddress(Address? address) {
    if (!mounted) return;
    // listenManual can fire synchronously during initState.
    if (!_listening) {
      _selectedAddress = address;
      return;
    }
    setState(() => _selectedAddress = address);
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _changeAddress() async {
    final picked = await showAppSheet<Object>(
      context,
      title: 'Delivery address',
      builder: (_) => _AddressSheet(selectedId: _selectedAddress?.id),
    );
    if (!mounted || picked == null) return;
    if (identical(picked, _addNewAddress)) {
      await _addAddress();
    } else if (picked is Address) {
      setState(() {
        _selectedAddress = picked;
        _error = null;
      });
    }
  }

  Future<void> _addAddress() async {
    final before = {
      for (final a in ref.read(addressControllerProvider).valueOrNull ??
          const <Address>[])
        a.id,
    };
    await Navigator.pushNamed(context, addNewAddressesScreenRoute);
    if (!mounted) return;
    final after = ref.read(addressControllerProvider).valueOrNull ?? const [];
    final added = after.where((a) => !before.contains(a.id));
    if (added.isNotEmpty) {
      setState(() {
        _selectedAddress = added.first;
        _error = null;
      });
    }
  }

  void _applyCoupon() {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _appliedCoupon = code.toUpperCase());
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
    });
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
    } on AuthRequiredException {
      if (!mounted) return;
      unawaited(
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
      );
    } catch (e) {
      if (mounted) setState(() => _error = orderErrorMessage(e));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartControllerProvider);
    final addressesAsync = ref.watch(addressControllerProvider);
    final c = context.colors;

    final cart = cartAsync.valueOrNull;
    final short = cart?.items.any((l) => l.quantity > l.available) ?? false;
    final String? blockReason = switch (cartAsync) {
      AsyncData(value: final cart) when cart.isEmpty => 'Your cart is empty',
      AsyncData() when short =>
        'Some items are short on stock — update your cart',
      AsyncData() when _selectedAddress == null =>
        'Add a delivery address to continue',
      _ => null,
    };
    final canPay = cart != null && !cartAsync.isLoading && blockReason == null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Checkout'),
      body: cartAsync.when(
        loading: () => const _CheckoutSkeleton(),
        error: (err, _) => err is AuthRequiredException
            ? EmptyState(
                icon: Icons.lock_rounded,
                title: 'Sign in to check out',
                message: cartErrorMessage(err),
                actionLabel: 'Sign in',
                onAction: () => Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
              )
            : ErrorState(
                error: err,
                message: cartErrorMessage(err),
                onRetry: () =>
                    ref.read(cartControllerProvider.notifier).refresh(),
              ),
        data: (cart) {
          if (cart.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_rounded,
              title: 'Your cart is empty',
              message: 'Add something to your cart before checking out.',
              actionLabel: 'Back to cart',
              onAction: () => Navigator.maybePop(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            children: [
              _StepIndicator(current: _selectedAddress == null ? 0 : 1),
              const SizedBox(height: AppSpacing.md),
              if (short) ...[
                InlineBanner(
                  tone: Tone.warning,
                  title: 'Stock changed',
                  message:
                      'Some items have less stock than you requested. Update quantities before paying.',
                  actionLabel: 'Back to cart',
                  onAction: () => Navigator.maybePop(context),
                ),
                const SizedBox(height: AppSpacing.smd),
              ],
              _AddressSection(
                address: _selectedAddress,
                addressesAsync: addressesAsync,
                enabled: !_paying,
                onChange: _changeAddress,
                onAdd: _addAddress,
                onRetry: () =>
                    ref.read(addressControllerProvider.notifier).refresh(),
              ),
              const SizedBox(height: AppSpacing.smd),
              _ItemsSection(
                cart: cart,
                expanded: _itemsExpanded,
                onToggle: () =>
                    setState(() => _itemsExpanded = !_itemsExpanded),
              ),
              const SizedBox(height: AppSpacing.smd),
              const _PaymentSection(),
              const SizedBox(height: AppSpacing.smd),
              _CouponSection(
                controller: _couponController,
                applied: _appliedCoupon,
                enabled: !_paying,
                onApply: _applyCoupon,
                onRemove: _removeCoupon,
              ),
              const SizedBox(height: AppSpacing.smd),
              SectionCard(
                title: 'Price summary',
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
                    if (_appliedCoupon != null)
                      SummaryRow(
                        label: 'Coupon ($_appliedCoupon)',
                        value: 'Applied at payment',
                        valueColor: c.success,
                      ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1, color: c.divider),
                    ),
                    SummaryRow(
                      label: 'Total',
                      value: formatInr(cart.total),
                      emphasize: true,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Coupon discounts, if any, are applied when you pay. Prices include all taxes.',
                      style: context.text.captionMuted,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _PayBar(
        total: cart?.total,
        reason: blockReason,
        error: _error,
        paying: _paying,
        onPay: canPay ? _pay : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  /// 0 = Address, 1 = Payment, 2 = Done.
  final int current;

  static const _labels = ['Address', 'Payment', 'Done'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      final done = i < current;
      final active = i == current;
      final color = done || active ? c.primary : c.textDisabled;
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppDurations.normal,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? c.primary : (active ? c.primarySoft : c.surface),
                border: Border.all(color: color, width: 1.5),
              ),
              alignment: Alignment.center,
              child: done
                  ? Icon(Icons.check_rounded, size: 14, color: c.textOnPrimary)
                  : Text(
                      '${i + 1}',
                      style: context.text.badge.copyWith(color: color),
                    ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              _labels[i],
              style: context.text.label.copyWith(
                color: active
                    ? c.textPrimary
                    : (done ? c.textSecondary : c.textMuted),
              ),
            ),
          ],
        ),
      );
      if (i < _labels.length - 1) {
        children.add(
          Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: i < current ? c.primary : c.border,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(children: children),
    );
  }
}

// ---------------------------------------------------------------------------
// Address
// ---------------------------------------------------------------------------

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.address,
    required this.addressesAsync,
    required this.enabled,
    required this.onChange,
    required this.onAdd,
    required this.onRetry,
  });

  final Address? address;
  final AsyncValue<List<Address>> addressesAsync;
  final bool enabled;
  final VoidCallback onChange;
  final VoidCallback onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = address;

    Widget body;
    if (selected != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 20,
              color: c.onPrimarySoft,
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        selected.name,
                        style: context.text.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected.isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusPill(label: 'Default', tone: Tone.primary),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(selected.oneLine, style: context.text.bodySecondary),
                const SizedBox(height: AppSpacing.xxs),
                Text(selected.phone, style: context.text.caption),
              ],
            ),
          ),
        ],
      );
    } else if (addressesAsync.isLoading && !addressesAsync.hasValue) {
      body = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 14, width: 140),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(height: 12, width: 220),
        ],
      );
    } else if (addressesAsync.hasError && !addressesAsync.hasValue) {
      body = InlineBanner(
        tone: Tone.error,
        message: friendlyError(addressesAsync.error),
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where should we deliver your order?',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppButton.secondary(
            label: 'Add delivery address',
            icon: Icons.add_location_alt_rounded,
            size: AppButtonSize.md,
            onPressed: enabled ? onAdd : null,
          ),
        ],
      );
    }

    return SectionCard(
      title: 'Delivery address',
      icon: Icons.local_shipping_rounded,
      trailing: selected == null
          ? null
          : AppButton.ghost(
              label: 'Change',
              size: AppButtonSize.sm,
              onPressed: enabled ? onChange : null,
            ),
      child: body,
    );
  }
}

class _AddressSheet extends ConsumerWidget {
  const _AddressSheet({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final addressesAsync = ref.watch(addressControllerProvider);
    final addresses = addressesAsync.valueOrNull ?? const <Address>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (addressesAsync.isLoading && addresses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: ListRowSkeleton(thumb: 40),
          ),
        for (final a in addresses) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.smd),
            borderColor: a.id == selectedId ? c.primary : null,
            color: a.id == selectedId ? c.primarySoft : null,
            onTap: () => Navigator.pop(context, a),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a.id == selectedId
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: a.id == selectedId ? c.primary : c.textMuted,
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.name,
                              style: context.text.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (a.isDefault) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const StatusPill(
                              label: 'Default',
                              tone: Tone.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(a.oneLine, style: context.text.bodySecondary),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(a.phone, style: context.text.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        AppButton.outline(
          label: 'Add new address',
          icon: Icons.add_rounded,
          size: AppButtonSize.md,
          onPressed: () => Navigator.pop(context, _addNewAddress),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Items
// ---------------------------------------------------------------------------

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({
    required this.cart,
    required this.expanded,
    required this.onToggle,
  });

  final Cart cart;
  final bool expanded;
  final VoidCallback onToggle;

  static const _maxThumbs = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = cart.items;
    final extra = lines.length - _maxThumbs;

    return SectionCard(
      title: 'Items',
      icon: Icons.shopping_bag_rounded,
      trailing: Text(
        '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
        style: context.text.caption,
      ),
      child: AnimatedSize(
        duration: AppDurations.normal,
        curve: AppCurves.standard,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!expanded)
              Row(
                children: [
                  for (final line in lines.take(_maxThumbs)) ...[
                    OrderThumb(
                      size: 48,
                      child: CatalogImage(
                        source: line.image,
                        isRemote: line.hasRemoteImage,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (extra > 0)
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surfaceSunken,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text('+$extra', style: context.text.label),
                    ),
                ],
              )
            else
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.smd),
                  child: Row(
                    children: [
                      OrderThumb(
                        size: 48,
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
                            Text(
                              line.name,
                              style: context.text.titleSm,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Qty ${line.quantity} · ${formatInr(line.price)} ${formatUnit(line.unit)}',
                              style: context.text.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatInr(line.lineTotal),
                        style: context.text.bodyStrong,
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.ghost(
                label: expanded ? 'Hide items' : 'View all items',
                size: AppButtonSize.sm,
                trailingIcon: expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                onPressed: onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

class _PaymentSection extends StatelessWidget {
  const _PaymentSection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SectionCard(
      title: 'Payment',
      icon: Icons.account_balance_wallet_rounded,
      trailing: const StatusPill(label: 'Prepaid', tone: Tone.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pay securely online — you’ll pick your method in the next step.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.smd),
          Container(
            decoration: BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: AppRadius.mdAll,
            ),
            child: const Column(
              children: [
                _PaymentRow(
                  icon: Icons.qr_code_2_rounded,
                  title: 'UPI',
                  subtitle: 'Google Pay, PhonePe, Paytm & more',
                ),
                _PaymentDivider(),
                _PaymentRow(
                  icon: Icons.credit_card_rounded,
                  title: 'Credit & debit cards',
                  subtitle: 'Visa, Mastercard, RuPay',
                ),
                _PaymentDivider(),
                _PaymentRow(
                  icon: Icons.account_balance_rounded,
                  title: 'Netbanking',
                  subtitle: 'All major Indian banks',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 14, color: c.success),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Secured by Razorpay · Cash on delivery isn’t available',
                  style: context.text.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.smd - 2,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: c.border),
            ),
            child: Icon(icon, size: 20, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSm),
                Text(subtitle, style: context.text.caption),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, size: 18, color: c.success),
        ],
      ),
    );
  }
}

class _PaymentDivider extends StatelessWidget {
  const _PaymentDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: AppSpacing.smd,
        endIndent: AppSpacing.smd,
        color: context.colors.divider,
      );
}

// ---------------------------------------------------------------------------
// Coupon
// ---------------------------------------------------------------------------

class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.controller,
    required this.applied,
    required this.enabled,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String? applied;
  final bool enabled;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final code = applied;
    return SectionCard(
      title: 'Coupon',
      icon: Icons.local_offer_rounded,
      child: AnimatedSwitcher(
        duration: AppDurations.fast,
        child: code != null
            ? Container(
                key: const ValueKey('applied'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.smd,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: c.successSoft,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20, color: c.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(code, style: context.text.title),
                          Text(
                            'Discount is validated and applied when you pay',
                            style: context.text.caption,
                          ),
                        ],
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Remove coupon',
                      size: 36,
                      iconSize: 18,
                      color: c.textSecondary,
                      onPressed: enabled ? onRemove : null,
                    ),
                  ],
                ),
              )
            : Row(
                key: const ValueKey('entry'),
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onApply(),
                      style: context.text.body,
                      decoration: const InputDecoration(
                        hintText: 'Enter coupon code',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => AppButton.secondary(
                      label: 'Apply',
                      size: AppButtonSize.md,
                      expand: false,
                      onPressed: enabled && controller.text.trim().isNotEmpty
                          ? onApply
                          : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky pay bar
// ---------------------------------------------------------------------------

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.total,
    required this.reason,
    required this.error,
    required this.paying,
    required this.onPay,
  });

  final num? total;
  final String? reason;
  final String? error;
  final bool paying;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount = total;
    return DecoratedBox(
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
              if (error != null) ...[
                InlineBanner(tone: Tone.error, message: error!),
                const SizedBox(height: AppSpacing.smd),
              ] else if (reason != null) ...[
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        reason!,
                        style: context.text.caption.copyWith(color: c.warning),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppButton(
                label: paying
                    ? 'Opening payment…'
                    : amount == null
                        ? 'Pay'
                        : 'Pay ${formatInr(amount)}',
                icon: Icons.lock_rounded,
                loading: paying,
                onPressed: onPay,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_rounded, size: 13, color: c.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '100% secure payments by Razorpay',
                    style: context.text.captionMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _CheckoutSkeleton extends StatelessWidget {
  const _CheckoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: const [
        ShimmerBox(height: 22, borderRadius: AppRadius.pillAll),
        SizedBox(height: AppSpacing.md),
        ShimmerBox(height: 120, borderRadius: AppRadius.mdAll),
        SizedBox(height: AppSpacing.smd),
        ShimmerBox(height: 110, borderRadius: AppRadius.mdAll),
        SizedBox(height: AppSpacing.smd),
        ShimmerBox(height: 200, borderRadius: AppRadius.mdAll),
        SizedBox(height: AppSpacing.smd),
        ShimmerBox(height: 140, borderRadius: AppRadius.mdAll),
      ],
    );
  }
}
