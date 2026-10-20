import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/ui/ui.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/address_data.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';
import 'payment_flow.dart';

/// Returned by the address sheet when the user taps "Add new address".
const _addNewAddress = Object();

/// Single-page checkout: delivery address, order items, payment, coupon,
/// price summary, pay. The payment method itself (UPI/card/netbanking) is
/// chosen inside the Razorpay widget, not here. The app is prepaid only (a
/// product decision — the API also offers COD), so checkout always sends
/// `paymentMethod: ONLINE`.
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
      title: 'Deliver to',
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

  Future<void> _viewOffers() async {
    final code = await showAppSheet<String>(
      context,
      title: 'Offers for you',
      builder: (_) => const _OffersSheet(),
    );
    if (code == null || !mounted) return;
    _couponController.text = code;
    _applyCoupon();
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

      final result = await ref.read(paymentSheetLauncherProvider)(
        checkoutOrder,
      );

      if (!mounted) return;

      // Whatever the sheet reported, the order now exists — go to it and
      // let the processing screen verify (SDK success) or poll (error or
      // dismissal). A failed attempt is retried there via
      // `POST /orders/{id}/pay`, never by checking out again (that would
      // create a second order while this one keeps its stock held).
      unawaited(
        Navigator.pushReplacementNamed(
          context,
          orderProcessingScreenRoute,
          arguments: processingArgsFor(checkoutOrder.orderId, result),
        ),
      );
    } on AuthRequiredException {
      if (!mounted) return;
      unawaited(
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = orderErrorMessage(e));
      // 409 = stock/coupon/seller conflict: re-read the cart so the screen
      // matches the server.
      if (e is ApiException && e.isConflict) {
        unawaited(ref.read(cartControllerProvider.notifier).refresh());
      }
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
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              if (short)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    0,
                  ),
                  child: InlineBanner(
                    tone: Tone.warning,
                    message:
                        'Stock changed for some items. Update quantities before paying.',
                    actionLabel: 'Back to cart',
                    onAction: () => Navigator.maybePop(context),
                  ),
                ),
              _AddressSection(
                address: _selectedAddress,
                addressesAsync: addressesAsync,
                enabled: !_paying,
                onChange: _changeAddress,
                onAdd: _addAddress,
                onRetry: () =>
                    ref.read(addressControllerProvider.notifier).refresh(),
              ),
              const SectionDivider(thin: true),
              _ItemsSection(
                cart: cart,
                expanded: _itemsExpanded,
                onToggle: () =>
                    setState(() => _itemsExpanded = !_itemsExpanded),
              ),
              const SectionDivider(thin: true),
              const _PaymentSection(),
              const SectionDivider(thin: true),
              _CouponSection(
                controller: _couponController,
                applied: _appliedCoupon,
                enabled: !_paying,
                onApply: _applyCoupon,
                onRemove: _removeCoupon,
                onViewOffers: _viewOffers,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.mdPlus,
                    AppSpacing.md,
                    AppSpacing.mdPlus,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      if (_appliedCoupon != null)
                        SummaryRow(
                          label: 'Coupon $_appliedCoupon',
                          value: 'At payment',
                          valueColor: c.success,
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(height: 1, color: c.border),
                      ),
                      SummaryRow(
                        label: 'Total',
                        value: formatInr(cart.total),
                        emphasize: true,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Inclusive of all taxes. Coupon discounts are applied when you pay.',
                        style: context.text.captionMuted,
                      ),
                    ],
                  ),
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
    final selected = address;

    Widget body;
    if (selected != null) {
      body = _AddressText(address: selected);
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            expand: false,
            onPressed: enabled ? onAdd : null,
          ),
        ],
      );
    }

    return _CheckoutBlock(
      title: 'Deliver to',
      trailing: selected == null
          ? null
          : TextAction(label: 'Change', onTap: enabled ? onChange : null),
      child: body,
    );
  }
}

/// Name, full address and phone as plain text — no box.
class _AddressText extends StatelessWidget {
  const _AddressText({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                address.name,
                style: context.text.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (address.isDefault) ...[
              const SizedBox(width: AppSpacing.sm),
              const StatusPill(label: 'Default', tone: Tone.primary),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(address.oneLine, style: context.text.bodySecondary),
        const SizedBox(height: AppSpacing.xxs),
        Text(address.phone, style: context.text.captionMuted),
      ],
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
            padding: const EdgeInsets.all(AppSpacing.md),
            // Only the chosen address is framed; the rest sit on the sheet.
            borderColor: a.id == selectedId ? c.primary : null,
            color: a.id == selectedId ? c.tint : c.surface,
            onTap: () => Navigator.pop(context, a),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a.id == selectedId
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: AppIconSize.md,
                  color: a.id == selectedId ? c.primary : c.textMuted,
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(child: _AddressText(address: a)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.smd),
        AppButton.secondary(
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
// Section scaffold
// ---------------------------------------------------------------------------

/// Un-boxed checkout section: bold title (optional trailing action) and its
/// content, sitting directly on the canvas.
class _CheckoutBlock extends StatelessWidget {
  const _CheckoutBlock({
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.mdPlus,
        AppSpacing.gutter,
        AppSpacing.mdPlus,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.h3),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle!, style: context.text.captionMuted),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                Transform.translate(
                  offset: const Offset(AppSpacing.sm, 0),
                  child: trailing,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd + 2),
          child,
        ],
      ),
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

  static const _collapsedCount = 2;

  @override
  Widget build(BuildContext context) {
    final lines = cart.items;
    final collapsible = lines.length > _collapsedCount + 1;
    final shown =
        collapsible && !expanded ? lines.take(_collapsedCount) : lines;

    return _CheckoutBlock(
      title: 'Items',
      trailing: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Text(
          itemCountLabel(cart.itemCount),
          style: context.text.captionMuted,
        ),
      ),
      child: AnimatedSize(
        duration: AppDurations.normal,
        curve: AppCurves.standard,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.smd),
                child: Row(
                  children: [
                    ProductTile(image: line.image, size: 56),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: context.text.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Qty ${line.quantity} · ${formatInr(line.price)} ${formatUnit(line.unit)}',
                            style: context.text.captionMuted,
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
            if (collapsible)
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-AppSpacing.sm, 0),
                  child: TextAction(
                    label: expanded
                        ? 'Show less'
                        : 'Show all ${lines.length} items',
                    icon: expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    onTap: onToggle,
                  ),
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
    return _CheckoutBlock(
      title: 'Payment',
      subtitle: 'Prepaid only — pick your method in the next step',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PaymentRow(
            icon: Icons.qr_code_2_rounded,
            title: 'UPI',
            subtitle: 'Google Pay, PhonePe, Paytm & more',
          ),
          const _PaymentRow(
            icon: Icons.credit_card_rounded,
            title: 'Credit & debit cards',
            subtitle: 'Visa, Mastercard, RuPay',
          ),
          const _PaymentRow(
            icon: Icons.account_balance_rounded,
            title: 'Netbanking',
            subtitle: 'All major Indian banks',
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: AppIconSize.xs,
                color: c.success,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text('Secured by Razorpay', style: context.text.caption),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.smd + 2),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
            child: Icon(icon, size: AppIconSize.sm + 2, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.smd + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.title),
                Text(subtitle, style: context.text.captionMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    required this.onViewOffers,
  });

  final TextEditingController controller;
  final String? applied;
  final bool enabled;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final VoidCallback onViewOffers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final code = applied;
    const pill = OutlineInputBorder(
      borderRadius: AppRadius.pillAll,
      borderSide: BorderSide.none,
    );
    return _CheckoutBlock(
      title: 'Coupon',
      child: AnimatedSwitcher(
        duration: AppDurations.fast,
        child: code != null
            ? Row(
                key: const ValueKey('applied'),
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: AppIconSize.md,
                    color: c.success,
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(code, style: context.text.title),
                        Text(
                          'Validated and applied when you pay',
                          style: context.text.captionMuted,
                        ),
                      ],
                    ),
                  ),
                  TextAction(
                    label: 'Remove',
                    onTap: enabled ? onRemove : null,
                  ),
                ],
              )
            : Column(
                key: const ValueKey('entry'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: AppButtonSize.md.height,
                          child: TextField(
                            controller: controller,
                            enabled: enabled,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => onApply(),
                            style: context.text.bodyStrong,
                            decoration: InputDecoration(
                              hintText: 'Enter coupon code',
                              isDense: true,
                              filled: true,
                              fillColor: c.tint,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.mdPlus,
                                vertical: AppSpacing.smd + 1,
                              ),
                              prefixIcon: Icon(
                                Icons.local_offer_rounded,
                                size: AppIconSize.sm,
                                color: c.textMuted,
                              ),
                              border: pill,
                              enabledBorder: pill,
                              disabledBorder: pill,
                              focusedBorder: pill.copyWith(
                                borderSide:
                                    BorderSide(color: c.primary, width: 1.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => AppButton(
                          label: 'Apply',
                          size: AppButtonSize.md,
                          expand: false,
                          onPressed:
                              enabled && controller.text.trim().isNotEmpty
                                  ? onApply
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(-AppSpacing.sm, 0),
                    child: TextAction(
                      label: 'View offers',
                      icon: Icons.chevron_right_rounded,
                      onTap: enabled ? onViewOffers : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// `GET /discounts/offers` — coupons this customer can apply now. Pops the
/// chosen code.
class _OffersSheet extends ConsumerWidget {
  const _OffersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(couponOffersProvider).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => ErrorState(
            compact: true,
            error: err,
            message: orderErrorMessage(err),
            onRetry: () => ref.invalidate(couponOffersProvider),
          ),
          data: (offers) => offers.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.local_offer_outlined,
                  title: 'No offers right now',
                  message: 'Have a code? Enter it in the coupon field.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < offers.length; i++) ...[
                      if (i > 0) const Hairline(),
                      _OfferRow(offer: offers[i]),
                    ],
                  ],
                ),
        );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});

  final CouponOffer offer;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final terms = [
      if (o.minCartValue != null)
        'On orders above ${formatInr(o.minCartValue!)}',
      if (o.firstOrderOnly) 'First order only',
      if (o.personal) 'Just for you',
      if (o.expiresAt != null)
        'Valid till ${DateFormat('d MMM').format(o.expiresAt!)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${o.code} · ${o.headline}', style: context.text.title),
                if (o.description case final d? when d.isNotEmpty)
                  Text(d, style: context.text.bodySecondary),
                if (terms.isNotEmpty)
                  Text(terms, style: context.text.captionMuted),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton.outline(
            label: 'Apply',
            size: AppButtonSize.sm,
            expand: false,
            onPressed: () => Navigator.pop(context, o.code),
          ),
        ],
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
    final message = error ?? reason;
    final messageColor = error != null ? c.error : c.warning;
    return StickyFooter(
      bottom: context.bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    error != null
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: AppIconSize.xs + 2,
                    color: messageColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    message,
                    style: context.text.caption.copyWith(color: messageColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.smd),
          ],
          AppButton(
            label: paying
                ? 'Opening payment…'
                : amount == null
                    ? 'Pay securely'
                    : 'Pay ${formatInr(amount)}',
            icon: Icons.lock_rounded,
            loading: paying,
            onPressed: onPay,
          ),
        ],
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
    Widget block(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.mdPlus),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      children: [
        block(const [
          ShimmerBox(height: 18, width: 110),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(height: 14, width: 160),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(height: 12, width: 260),
        ]),
        const Hairline(),
        block(const [
          ShimmerBox(height: 18, width: 80),
          SizedBox(height: AppSpacing.md),
          ListRowSkeleton(thumb: 56),
          SizedBox(height: AppSpacing.smd),
          ListRowSkeleton(thumb: 56),
        ]),
        const Hairline(),
        block(const [
          ShimmerBox(height: 18, width: 100),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(height: 140, borderRadius: AppRadius.lgAll),
        ]),
      ],
    );
  }
}
