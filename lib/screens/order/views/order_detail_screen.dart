import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../components/ui/ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../models/cart_state.dart' show AuthRequiredException;
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../reviews/view/write_review_sheet.dart';
import 'order_ui.dart';

/// The normal fulfillment progression. Cancelled/returned orders render a
/// short, distinct timeline instead — see [_Timeline].
const _flow = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.packed,
  OrderStatus.shipped,
  OrderStatus.delivered,
];

const _flowCopy = {
  OrderStatus.placed: 'We’ve received your order',
  OrderStatus.confirmed: 'Payment confirmed',
  OrderStatus.packed: 'Packed and ready to ship',
  OrderStatus.shipped: 'On its way to you',
  OrderStatus.delivered: 'Delivered to your address',
};

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
    final number = orderAsync.valueOrNull?.orderNumber;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(
        title: number == null
            ? 'Order details'
            : 'Order ${orderDisplayNumber(number)}',
      ),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.fabClearance,
            ),
            children: [
              _StatusCard(order: order),
              const SizedBox(height: AppSpacing.smd),
              _ItemsCard(order: order),
              if (order.address != null) ...[
                const SizedBox(height: AppSpacing.smd),
                _AddressCard(address: order.address!),
              ],
              const SizedBox(height: AppSpacing.smd),
              _PaymentCard(order: order),
              const SizedBox(height: AppSpacing.smd),
              _HelpCard(order: order),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status + timeline
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});

  final Order order;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: order.orderNumber));
    if (context.mounted) AppSnack.success(context, 'Order number copied');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = orderStatusTone(order.status);
    final isTerminal = order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.returned;
    final isUnknown = order.status == OrderStatus.unknown;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORDER STATUS', style: context.text.overline),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      switch (order.status) {
                        OrderStatus.cancelled => 'This order was cancelled',
                        OrderStatus.returned => 'This order was returned',
                        _ => _flowCopy[order.status] ??
                            orderStatusLabel(order.status, order.rawStatus),
                      },
                      style: context.text.h3,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Placed ${formatOrderDateTime(order.createdAt)}',
                      style: context.text.caption,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: orderStatusLabel(order.status, order.rawStatus),
                tone: tone,
                icon: orderStatusIcon(order.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          InkWell(
            borderRadius: AppRadius.smAll,
            onTap: () => _copy(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                children: [
                  Text('Order no.', style: context.text.caption),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      orderDisplayNumber(order.orderNumber),
                      style: context.text.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 16, color: c.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: AppSpacing.md),
          if (isUnknown)
            InlineBanner(
              tone: Tone.info,
              message:
                  'Status: ${orderStatusLabel(order.status, order.rawStatus)}. Contact support if you have questions about this order.',
            )
          else if (isTerminal)
            _TerminalTimeline(status: order.status)
          else
            _Timeline(currentIndex: _flow.indexOf(order.status)),
        ],
      ),
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
            title: orderStatusLabel(_flow[i], ''),
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
  const _TerminalTimeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status == OrderStatus.cancelled;
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
          title: cancelled ? 'Cancelled' : 'Returned',
          subtitle: cancelled
              ? 'This order was cancelled'
              : 'This order was returned',
          state: _StepState.failed,
          connectorFilled: false,
          isLast: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        InlineBanner(
          tone: cancelled ? Tone.error : Tone.neutral,
          message: cancelled
              ? 'If any amount was debited for this order, reach out to support and we’ll help sort it out.'
              : 'Questions about your return? Our support team can help.',
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final Widget node = switch (state) {
      _StepState.done => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 15, color: c.textOnPrimary),
        ),
      _StepState.current => Container(
          width: 24,
          height: 24,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(color: c.primary, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
          ),
        ),
      _StepState.upcoming => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: c.borderStrong, width: 1.5),
          ),
        ),
      _StepState.failed => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
          child: Icon(Icons.close_rounded, size: 15, color: c.textOnPrimary),
        ),
    };

    final titleStyle = switch (state) {
      _StepState.current => context.text.title.copyWith(color: c.primary),
      _StepState.failed => context.text.title.copyWith(color: c.error),
      _StepState.done => context.text.title,
      _StepState.upcoming => context.text.title.copyWith(color: c.textMuted),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                node,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: connectorFilled ? c.primary : c.border,
                        borderRadius: AppRadius.pillAll,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2,
                bottom: isLast ? 0 : AppSpacing.mdPlus,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: titleStyle)),
                      if (state == _StepState.current) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const StatusPill(label: 'Now', tone: Tone.primary),
                      ],
                    ],
                  ),
                  if (subtitle != null && state != _StepState.upcoming) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: context.text.caption),
                  ],
                ],
              ),
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

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delivered = order.status == OrderStatus.delivered;
    final count = order.items.fold<int>(0, (s, i) => s + i.quantity);

    return SectionCard(
      title: 'Items',
      icon: Icons.shopping_bag_rounded,
      trailing: Text(
        '$count ${count == 1 ? 'item' : 'items'}',
        style: context.text.caption,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPad,
        AppSpacing.cardPad,
        AppSpacing.cardPad,
        AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < order.items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.divider),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderThumb(
              size: 60,
              child: CatalogImage(
                source: item.image,
                isRemote: item.hasRemoteImage,
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: context.text.titleSm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Qty ${item.quantity} · ${formatInr(item.unitPrice)} each',
                    style: context.text.caption,
                  ),
                  if (canReview) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.secondary(
                      label: 'Write a review',
                      icon: Icons.rate_review_rounded,
                      size: AppButtonSize.sm,
                      expand: false,
                      onPressed: () => _writeReview(context),
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
// Address, payment, help
// ---------------------------------------------------------------------------

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final OrderAddress address;

  @override
  Widget build(BuildContext context) {
    final line2 = address.line2;
    return SectionCard(
      title: 'Delivery address',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address.name, style: context.text.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(address.line1, style: context.text.bodySecondary),
          if (line2 != null && line2.isNotEmpty)
            Text(line2, style: context.text.bodySecondary),
          Text(
            '${address.city}, ${address.state} ${address.pincode}',
            style: context.text.bodySecondary,
          ),
          if (address.phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.phone_rounded,
                  size: 14,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(address.phone, style: context.text.caption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final itemsTotal =
        order.items.fold<num>(0, (sum, i) => sum + i.totalPrice);
    final discount = itemsTotal - order.amount;

    final (String label, Tone tone) = switch (order.status) {
      OrderStatus.placed => ('Awaiting payment confirmation', Tone.warning),
      OrderStatus.cancelled ||
      OrderStatus.returned =>
        ('Prepaid via Razorpay', Tone.neutral),
      _ => ('Paid via Razorpay', Tone.success),
    };

    return SectionCard(
      title: 'Payment summary',
      icon: Icons.receipt_long_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SummaryRow(label: 'Item total', value: formatInr(itemsTotal)),
          if (discount > 0)
            SummaryRow(
              label: 'Discount',
              value: '-${formatInr(discount)}',
              valueColor: c.success,
            ),
          SummaryRow(label: 'Delivery', value: 'Free', valueColor: c.success),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: c.divider),
          ),
          SummaryRow(
            label: order.status == OrderStatus.placed ? 'Total' : 'Total paid',
            value: formatInr(order.amount),
            emphasize: true,
          ),
          const SizedBox(height: AppSpacing.smd),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: label,
              tone: tone,
              icon: Icons.lock_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: () => openWhatsAppSupport(
        context,
        message:
            'Hi IrriKart, I need help with my order ${orderDisplayNumber(order.orderNumber)}.',
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.successSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent_rounded, color: c.success),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help with this order?', style: context.text.title),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Chat with our team on WhatsApp',
                  style: context.text.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
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
    final c = context.colors;
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.border),
          ),
          child: child,
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(height: 12, width: 90),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerBox(height: 22, width: 160),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < 4; i++) ...[
                const Row(
                  children: [
                    ShimmerBox(
                      height: 24,
                      width: 24,
                      borderRadius: AppRadius.pillAll,
                    ),
                    SizedBox(width: AppSpacing.smd),
                    ShimmerBox(height: 14, width: 140),
                  ],
                ),
                const SizedBox(height: AppSpacing.mdPlus),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        card(
          const Column(
            children: [
              ListRowSkeleton(thumb: 60),
              SizedBox(height: AppSpacing.md),
              ListRowSkeleton(thumb: 60),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        const ShimmerBox(height: 120, borderRadius: AppRadius.mdAll),
      ],
    );
  }
}
