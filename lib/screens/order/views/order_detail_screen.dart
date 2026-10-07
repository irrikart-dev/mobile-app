import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              const SectionDivider(thin: true),
              _ItemsSection(order: order),
              if (order.address != null) ...[
                const SectionDivider(thin: true),
                _AddressSection(address: order.address!),
              ],
              const SectionDivider(thin: true),
              _PaymentSection(order: order),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = orderStatusTone(order.status);
    final isTerminal = order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.returned;
    final isUnknown = order.status == OrderStatus.unknown;

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
                label: orderStatusLabel(order.status, order.rawStatus),
                tone: tone,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            switch (order.status) {
              OrderStatus.cancelled => 'This order was cancelled',
              OrderStatus.returned => 'This order was returned',
              _ => _flowCopy[order.status] ??
                  orderStatusLabel(order.status, order.rawStatus),
            },
            style: context.text.h1,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Placed ${formatOrderDateTime(order.createdAt)}',
            style: context.text.captionMuted,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isUnknown)
            Text(
              'Status: ${orderStatusLabel(order.status, order.rawStatus)}. '
              'Contact support if you have questions about this order.',
              style: context.text.bodySecondary,
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
              ? 'If any amount was debited, support will help sort it out.'
              : 'Questions about your return? Support can help.',
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
// Address, payment, help
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
    final itemsTotal =
        order.items.fold<num>(0, (sum, i) => sum + i.totalPrice);
    final discount = itemsTotal - order.amount;

    final (String label, Color color) = switch (order.status) {
      OrderStatus.placed => ('Awaiting payment confirmation', c.warning),
      OrderStatus.cancelled ||
      OrderStatus.returned =>
        ('Prepaid via Razorpay', c.textMuted),
      _ => ('Paid via Razorpay', c.success),
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
                child: Divider(height: 1, color: c.border),
              ),
              SummaryRow(
                label:
                    order.status == OrderStatus.placed ? 'Total' : 'Total paid',
                value: formatInr(order.amount),
                emphasize: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: AppIconSize.xs,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    label,
                    style: context.text.caption.copyWith(color: color),
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
