import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/ui/ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../models/cart_state.dart' show AuthRequiredException;
import '../../../models/order_data.dart';
import '../../../models/returns_data.dart';
import '../../../route/route_constants.dart';
import '../../checkout/views/payment_flow.dart';
import '../../reviews/view/write_review_sheet.dart';
import 'order_actions.dart';
import 'order_ui.dart';

/// The normal fulfillment progression. Unpaid, cancelled and returned
/// orders render their own block instead — see [_StatusHeader].
const _flow = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.packed,
  OrderStatus.shipped,
  OrderStatus.delivered,
];

const _flowTitle = {
  OrderStatus.placed: 'Placed',
  OrderStatus.confirmed: 'Confirmed',
  OrderStatus.packed: 'Packed',
  OrderStatus.shipped: 'Shipped',
  OrderStatus.delivered: 'Delivered',
};

const _flowCopy = {
  OrderStatus.placed: 'We’ve received your order',
  OrderStatus.confirmed: 'Payment confirmed',
  OrderStatus.packed: 'Packed and ready to ship',
  OrderStatus.shipped: 'On its way to you',
  OrderStatus.delivered: 'Delivered to your address',
};

/// `8 Oct, 3:45 PM`
String _shortDateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);

/// Order detail from `GET /orders/{id}`.
///
/// The API exposes only the current [OrderStatus] (no per-step timestamps),
/// so the timeline shows *which* steps are done, not *when*.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Order details'),
      body: orderAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const _DetailSkeleton(),
        error: (err, _) => err is AuthRequiredException
            ? EmptyState(
                icon: Icons.lock_rounded,
                title: 'Sign in to view this order',
                message: orderErrorMessage(err),
                actionLabel: 'Sign in',
                onAction: () => Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
              )
            : ErrorState(
                error: err,
                message: orderErrorMessage(err),
                onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
              ),
        data: (order) => RefreshIndicator(
          color: c.primary,
          onRefresh: () async {
            ref.invalidate(orderDetailProvider(orderId));
            try {
              await ref.read(orderDetailProvider(orderId).future);
            } catch (_) {
              // Shown by the error branch.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: AppSpacing.xl + context.bottomInset,
            ),
            children: [
              _StatusHeader(order: order),
              if (order.returns.isNotEmpty) ...[
                const SectionDivider(thin: true),
                _ReturnSection(request: order.returns.first),
              ],
              if (order.shipment case final shipment?) ...[
                const SectionDivider(thin: true),
                _ShipmentSection(shipment: shipment),
              ],
              const SectionDivider(thin: true),
              _ItemsSection(order: order),
              if (order.address != null) ...[
                const SectionDivider(thin: true),
                _AddressSection(address: order.address!),
              ],
              const SectionDivider(thin: true),
              _PaymentSection(order: order),
              if (_ManageSection.hasActions(order)) ...[
                const SectionDivider(thin: true),
                _ManageSection(order: order),
              ],
              const SectionDivider(thin: true),
              _HelpRow(order: order),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gutter-padded block with an overline header.
class _Block extends StatelessWidget {
  const _Block({required this.label, required this.child, this.trailing});

  final String label;
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
          OverlineHeader(label, trailing: trailing),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status + timeline
// ---------------------------------------------------------------------------

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final Order order;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: order.orderNumber));
    if (context.mounted) AppSnack.success(context, 'Order number copied');
  }

  String get _headline => switch (order.status) {
        OrderStatus.placed => 'Complete your payment',
        OrderStatus.paymentFailed => 'Payment didn’t go through',
        OrderStatus.confirmed =>
          order.accepted ? 'Order confirmed' : 'Payment confirmed',
        OrderStatus.cancelled => 'This order was cancelled',
        OrderStatus.returned => 'This order was returned',
        OrderStatus.unknown => 'We’re processing your order',
        _ => _flowCopy[order.status]!,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _copy(context),
                borderRadius: AppRadius.smAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Order ${orderDisplayNumber(order.orderNumber)}',
                        style: context.text.label.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Icon(
                        Icons.copy_rounded,
                        size: AppIconSize.xs,
                        color: c.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              StatusPill(
                label: orderStatusLabel(order.status),
                tone: orderStatusTone(order.status),
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_headline, style: context.text.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Placed ${formatOrderDateTime(order.createdAt)}',
            style: context.text.captionMuted,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (order.awaitingPayment)
            _PaymentDue(order: order)
          else if (order.status == OrderStatus.unknown)
            Text(
              'We’ll update this order as soon as there’s news. Contact '
              'support if you have questions about it.',
              style: context.text.bodySecondary,
            )
          else if (order.status == OrderStatus.cancelled)
            _CancelledBlock(order: order)
          else if (order.status == OrderStatus.returned)
            const _TerminalTimeline(
              title: 'Returned',
              subtitle: 'Questions about your return? Support can help.',
            )
          else ...[
            if (order.awaitingSellerAcceptance) ...[
              const InlineBanner(
                tone: Tone.info,
                icon: Icons.storefront_rounded,
                title: 'Waiting for the seller to accept',
                message: 'Your payment is confirmed. The seller will accept '
                    'your order shortly, then pack it.',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _Timeline(currentIndex: _flow.indexOf(order.status)),
          ],
        ],
      ),
    );
  }
}

/// `PLACED` / `PAYMENT_FAILED`: the 30-minute window with a live countdown,
/// then Retry payment / Pay now and Cancel.
class _PaymentDue extends ConsumerStatefulWidget {
  const _PaymentDue({required this.order});

  final Order order;

  @override
  ConsumerState<_PaymentDue> createState() => _PaymentDueState();
}

class _PaymentDueState extends ConsumerState<_PaymentDue> {
  bool _paying = false;

  Order get _order => widget.order;

  Future<void> _pay() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      await retryOrderPayment(context, ref, _order.id);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _cancel() =>
      cancelOrderFlow(context, ref, orderId: _order.id);

  @override
  Widget build(BuildContext context) {
    final failed = _order.status == OrderStatus.paymentFailed;
    return TickingBuilder(
      until: _order.paymentDeadline,
      builder: (context, now) {
        final left = _order.paymentTimeLeft(now);
        final expired = left == Duration.zero;
        final canPay = _order.canPay(now);
        final countdown = formatCountdown(left);
        final until = DateFormat('h:mm a').format(_order.paymentDeadline);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expired)
              const InlineBanner(
                tone: Tone.neutral,
                icon: Icons.timer_off_outlined,
                title: 'Payment window closed',
                message: 'This order wasn’t paid within 30 minutes, so it '
                    'will be cancelled automatically and nothing will be '
                    'charged. Pull down to refresh.',
              )
            else if (failed)
              InlineBanner(
                tone: Tone.error,
                icon: Icons.credit_card_off_rounded,
                title: 'Payment failed · $countdown left',
                message: 'Your payment didn’t go through. Your items are '
                    'reserved for 30 minutes from when you placed the '
                    'order (until $until).',
              )
            else
              InlineBanner(
                tone: Tone.warning,
                icon: Icons.timer_outlined,
                title: 'Complete payment within 30 minutes',
                message: '$countdown left · your items are reserved until '
                    '$until. Unpaid orders are cancelled automatically.',
              ),
            const SizedBox(height: AppSpacing.md),
            if (canPay) ...[
              AppButton(
                label: failed ? 'Retry payment' : 'Pay now',
                icon: Icons.lock_rounded,
                loading: _paying,
                onPressed: _pay,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton.outline(
              label: 'Cancel order',
              onPressed: _paying ? null : _cancel,
            ),
          ],
        );
      },
    );
  }
}

/// Cancelled: why, by whom, when — and the refund, if it had been paid.
class _CancelledBlock extends ConsumerWidget {
  const _CancelledBlock({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = order.cancelReason;
    final by = cancelledByLabel(order.cancelledBy);
    final when = order.cancelledAt;
    final meta = [
      if (by != null) by,
      if (when != null) _shortDateTime(when),
    ].join(' · ');
    final refund = order.wasPaidOnline
        ? ref.watch(cancelRefundStatusProvider)[order.id] ??
            RefundStatus.started
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TerminalTimeline(
          title: 'Cancelled',
          subtitle: [
            if (reason != null && reason.isNotEmpty) '“$reason”',
            if (meta.isNotEmpty) meta,
          ].join('\n'),
        ),
        if (refund != null) ...[
          const SizedBox(height: AppSpacing.lg),
          RefundBanner(status: refund),
        ],
      ],
    );
  }
}

enum _StepState { done, current, upcoming, failed }

class _Timeline extends StatelessWidget {
  const _Timeline({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final deliveredAll = currentIndex == _flow.length - 1;
    return Column(
      children: [
        for (var i = 0; i < _flow.length; i++)
          _TimelineStep(
            title: _flowTitle[_flow[i]]!,
            subtitle: _flowCopy[_flow[i]],
            state: i < currentIndex || (deliveredAll && i == currentIndex)
                ? _StepState.done
                : i == currentIndex
                    ? _StepState.current
                    : _StepState.upcoming,
            connectorFilled: i < currentIndex,
            isLast: i == _flow.length - 1,
          ),
      ],
    );
  }
}

class _TerminalTimeline extends StatelessWidget {
  const _TerminalTimeline({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineStep(
          title: 'Placed',
          subtitle: _flowCopy[OrderStatus.placed],
          state: _StepState.done,
          connectorFilled: false,
          isLast: false,
        ),
        _TimelineStep(
          title: title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          state: _StepState.failed,
          connectorFilled: false,
          isLast: true,
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.connectorFilled,
    required this.isLast,
  });

  final String title;
  final String? subtitle;
  final _StepState state;
  final bool connectorFilled;
  final bool isLast;

  static const _node = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget disc(Color color, {Widget? child, double size = _node}) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: child,
        );

    final Widget node = switch (state) {
      _StepState.done => disc(
          c.primary,
          child: Icon(
            Icons.check_rounded,
            size: AppIconSize.xs,
            color: c.textOnPrimary,
          ),
        ),
      _StepState.current => disc(
          c.tint,
          child: disc(c.accent, size: 10),
        ),
      _StepState.upcoming =>
        disc(c.tint, child: disc(c.borderStrong, size: 8)),
      _StepState.failed => disc(
          c.error,
          child: Icon(
            Icons.close_rounded,
            size: AppIconSize.xs,
            color: c.textOnPrimary,
          ),
        ),
    };

    final titleStyle = switch (state) {
      _StepState.current => context.text.title.copyWith(
          fontWeight: FontWeight.w700,
        ),
      _StepState.failed => context.text.title.copyWith(color: c.error),
      _StepState.done => context.text.title,
      _StepState.upcoming => context.text.title.copyWith(color: c.textMuted),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _node,
            child: Column(
              children: [
                node,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: connectorFilled ? c.primary : c.divider,
                        borderRadius: AppRadius.pillAll,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 1,
                bottom: isLast ? 0 : AppSpacing.mdPlus,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null && state != _StepState.upcoming) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: context.text.captionMuted),
                  ],
                ],
              ),
            ),
          ),
          if (state == _StepState.current)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                'NOW',
                style: context.text.overline.copyWith(color: c.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items
// ---------------------------------------------------------------------------

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final delivered = order.status == OrderStatus.delivered;
    final count = order.items.fold<int>(0, (s, i) => s + i.quantity);

    return _Block(
      label: 'Items',
      trailing: Text(itemCountLabel(count), style: context.text.captionMuted),
      child: Column(
        children: [
          for (var i = 0; i < order.items.length; i++) ...[
            if (i > 0) const Hairline(),
            _OrderItemRow(item: order.items[i], canReview: delivered),
          ],
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item, required this.canReview});

  final OrderItem item;
  final bool canReview;

  void _writeReview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => WriteReviewSheet(
        productId: item.productId,
        orderItem: item,
        onSubmitted: () {
          if (context.mounted) {
            AppSnack.success(context, 'Thanks! Your review was submitted.');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        productDetailsScreenRoute,
        arguments: item.slug,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductTile(image: item.image, size: 64),
            const SizedBox(width: AppSpacing.smd + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: context.text.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Qty ${item.quantity} · ${formatInr(item.unitPrice)} each',
                    style: context.text.captionMuted,
                  ),
                  if (canReview) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Transform.translate(
                      offset: const Offset(-AppSpacing.sm, 0),
                      child: TextAction(
                        label: 'Write a review',
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _writeReview(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(formatInr(item.totalPrice), style: context.text.bodyStrong),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Address, payment, actions, help
// ---------------------------------------------------------------------------

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.address});

  final OrderAddress address;

  @override
  Widget build(BuildContext context) {
    final line2 = address.line2;
    return _Block(
      label: 'Delivery address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address.name, style: context.text.title),
          const SizedBox(height: AppSpacing.xs),
          Text(address.line1, style: context.text.bodySecondary),
          if (line2 != null && line2.isNotEmpty)
            Text(line2, style: context.text.bodySecondary),
          Text(
            '${address.city}, ${address.state} ${address.pincode}',
            style: context.text.bodySecondary,
          ),
          if (address.phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(address.phone, style: context.text.captionMuted),
          ],
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final method = paymentMethodLabel(order.paymentMethod) ?? 'Online';
    final paid = !order.awaitingPayment &&
        !(order.status == OrderStatus.cancelled && !order.wasPaidOnline);

    final (IconData icon, String note, Color color) = switch (order.status) {
      _ when order.isCod => (
          Icons.payments_rounded,
          'Pay on delivery',
          c.textSecondary,
        ),
      OrderStatus.placed => (
          Icons.schedule_rounded,
          'Awaiting payment',
          c.warning,
        ),
      OrderStatus.paymentFailed => (
          Icons.error_outline_rounded,
          'Last payment attempt failed',
          c.error,
        ),
      OrderStatus.cancelled when order.wasPaidOnline => (
          Icons.replay_rounded,
          'Refunded to your payment method',
          c.textSecondary,
        ),
      OrderStatus.cancelled => (
          Icons.block_rounded,
          'Not charged',
          c.textMuted,
        ),
      _ => (Icons.verified_user_rounded, 'Paid', c.success),
    };

    return _Block(
      label: 'Payment',
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
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
                label: 'Item total',
                value: formatInr(order.itemsTotal),
              ),
              if (order.discount > 0)
                SummaryRow(
                  label: 'Coupon discount',
                  value: '-${formatInr(order.discount)}',
                  valueColor: c.success,
                ),
              SummaryRow(label: 'Delivery', value: 'Free', valueColor: c.success),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: c.border),
              ),
              SummaryRow(
                label: paid ? 'Total paid' : 'Total',
                value: formatInr(order.amount),
                emphasize: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(icon, size: AppIconSize.xs, color: color),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      note,
                      style: context.text.caption.copyWith(color: color),
                    ),
                  ),
                  Text(method, style: context.text.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Invoice, reorder and (for a confirmed order inside 24 h) cancel — as
/// flat rows. Unpaid orders keep their actions next to the countdown.
class _ManageSection extends ConsumerStatefulWidget {
  const _ManageSection({required this.order});

  final Order order;

  static bool _showReorder(Order o) => !o.awaitingPayment && o.items.isNotEmpty;
  static bool _showCancel(Order o) => !o.awaitingPayment && o.canCancel();

  static bool hasActions(Order o) =>
      o.hasInvoice || _showReorder(o) || _showCancel(o) || o.canReturn();

  @override
  ConsumerState<_ManageSection> createState() => _ManageSectionState();
}

enum _Busy { invoice, reorder }

class _ManageSectionState extends ConsumerState<_ManageSection> {
  _Busy? _busy;

  Order get _order => widget.order;

  Future<void> _run(_Busy kind, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = kind);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _requestReturn() async {
    final sent = await Navigator.pushNamed<bool>(
      context,
      returnRequestScreenRoute,
      arguments: _order,
    );
    if (sent != true || !mounted) return;
    refetchOrder(ref, _order.id);
    AppSnack.success(context, 'Return requested. We’ll update you here.');
  }

  Widget? _spinner(_Busy kind) => _busy == kind
      ? Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.primary,
            ),
          ),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return _Block(
      label: 'Manage order',
      child: SettingsGroup(
        children: [
          if (order.hasInvoice)
            SettingsTile(
              icon: Icons.receipt_long_rounded,
              title: 'Download invoice',
              subtitle: 'PDF — view, save or share',
              trailing: _spinner(_Busy.invoice),
              showChevron: _busy != _Busy.invoice,
              onTap: () => _run(
                _Busy.invoice,
                () => downloadInvoiceFlow(
                  context,
                  ref,
                  orderId: order.id,
                  orderNumber: order.orderNumber,
                ),
              ),
            ),
          if (_ManageSection._showReorder(order))
            SettingsTile(
              icon: Icons.replay_rounded,
              title: 'Reorder',
              subtitle: 'Add these items to your cart again',
              trailing: _spinner(_Busy.reorder),
              showChevron: _busy != _Busy.reorder,
              onTap: () => _run(
                _Busy.reorder,
                () => reorderFlow(
                  context,
                  ref,
                  orderId: order.id,
                  items: order.items,
                ),
              ),
            ),
          if (order.canReturn())
            SettingsTile(
              icon: Icons.assignment_return_rounded,
              title: 'Return items',
              subtitle: 'Return or replace until '
                  '${_shortDateTime(order.returnableUntil!)}',
              onTap: _busy != null ? null : _requestReturn,
            ),
          if (_ManageSection._showCancel(order))
            SettingsTile(
              icon: Icons.cancel_outlined,
              title: 'Cancel order',
              subtitle: 'Free cancellation until '
                  '${_shortDateTime(order.createdAt.add(orderCancelWindow))}',
              destructive: true,
              onTap: _busy != null
                  ? null
                  : () => unawaited(
                        cancelOrderFlow(context, ref, orderId: order.id),
                      ),
            ),
        ],
      ),
    );
  }
}

/// The latest return request: status, what's in it, and staff's note.
class _ReturnSection extends StatelessWidget {
  const _ReturnSection({required this.request});

  final ReturnRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final tone = switch (r.status) {
      ReturnStatus.completed => Tone.success,
      ReturnStatus.rejected => Tone.error,
      ReturnStatus.approved => Tone.info,
      _ => Tone.warning,
    };
    final message = switch (r.status) {
      ReturnStatus.requested => 'Our team is reviewing your request.',
      ReturnStatus.approved => 'Approved. Our team will arrange the pickup.',
      ReturnStatus.completed => r.isReplacement
          ? 'Return complete — our team will contact you about the '
              'replacement.'
          : 'Return complete — our team will contact you about the refund.',
      ReturnStatus.rejected => 'Your request was declined.',
      ReturnStatus.unknown => 'We’ll update you here.',
    };
    final units = r.items.fold<int>(0, (s, i) => s + i.quantity);
    return _Block(
      label: r.isReplacement ? 'Replacement' : 'Return',
      trailing: StatusPill(
        label: returnStatusLabel(r.status),
        tone: tone,
        dot: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: context.text.body),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${itemCountLabel(units)} · “${r.reason}” · '
            '${_shortDateTime(r.createdAt)}',
            style: context.text.captionMuted,
          ),
          if (r.adminNote case final note? when note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.smd),
            InlineBanner(
              tone: r.status == ReturnStatus.rejected ? Tone.error : Tone.info,
              icon: Icons.support_agent_rounded,
              title: 'Note from IrriKart',
              message: note,
            ),
          ],
        ],
      ),
    );
  }
}

/// Courier tracking. Its status is the courier's, independent of the
/// order's (staff mark the order delivered).
class _ShipmentSection extends StatelessWidget {
  const _ShipmentSection({required this.shipment});

  final Shipment shipment;

  Future<void> _copyAwb(BuildContext context, String awb) async {
    await Clipboard.setData(ClipboardData(text: awb));
    if (context.mounted) AppSnack.success(context, 'Tracking number copied');
  }

  @override
  Widget build(BuildContext context) {
    final awb = shipment.awbNumber;
    final label = switch (shipment.status) {
      'CREATED' => 'Booked',
      'IN_TRANSIT' => 'In transit',
      'DELIVERED' => 'Delivered',
      'RTO' => 'Returning to seller',
      'FAILED' => 'Delivery failed',
      _ => 'Processing',
    };
    return _Block(
      label: 'Shipment',
      trailing: Text(label, style: context.text.captionMuted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (awb != null && awb.isNotEmpty)
            InkWell(
              onTap: () => _copyAwb(context, awb),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Text('Tracking no. $awb', style: context.text.bodyStrong),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Icon(
                      Icons.copy_rounded,
                      size: AppIconSize.xs,
                      color: context.colors.textMuted,
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'Tracking number not assigned yet.',
              style: context.text.bodySecondary,
            ),
          // Newest first reads better on a phone.
          for (final e in shipment.events.reversed) ...[
            const SizedBox(height: AppSpacing.smd),
            Text(e.description ?? e.status, style: context.text.body),
            Text(
              '${e.status} · ${_shortDateTime(e.occurredAt)}',
              style: context.text.captionMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => openWhatsAppSupport(
        context,
        message:
            'Hi IrriKart, I need help with my order ${orderDisplayNumber(order.orderNumber)}.',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.mdPlus,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
              child: Icon(
                Icons.support_agent_rounded,
                size: AppIconSize.md,
                color: c.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.smd + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need help with this order?', style: context.text.title),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Chat with our team on WhatsApp',
                    style: context.text.captionMuted,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      children: [
        const ShimmerBox(height: 12, width: 110),
        const SizedBox(height: AppSpacing.smd),
        const ShimmerBox(height: 26, width: 220),
        const SizedBox(height: AppSpacing.sm),
        const ShimmerBox(height: 12, width: 150),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 4; i++) ...[
          const Row(
            children: [
              ShimmerBox(
                height: 22,
                width: 22,
                borderRadius: AppRadius.pillAll,
              ),
              SizedBox(width: AppSpacing.md),
              ShimmerBox(height: 14, width: 140),
            ],
          ),
          const SizedBox(height: AppSpacing.mdPlus),
        ],
        const Hairline(),
        const SizedBox(height: AppSpacing.mdPlus),
        const ListRowSkeleton(thumb: 64),
        const SizedBox(height: AppSpacing.md),
        const ListRowSkeleton(thumb: 64),
      ],
    );
  }
}
