import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_data.dart';

/// The normal fulfillment progression. A cancelled/returned order (or a
/// status this build doesn't recognise) shows a status banner instead —
/// see [_StatusSection].
const _flow = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.packed,
  OrderStatus.shipped,
  OrderStatus.delivered,
];

/// Order detail: status + line items + total, from `GET /orders/{id}`.
///
/// Unlike the old mock data, there is no per-step timestamp from the API —
/// only the current [OrderStatus] — so the timeline shows *which* steps are
/// done, not *when* each one happened.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar:
          AppBar(title: Text(orderAsync.valueOrNull?.orderNumber ?? 'Order')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(orderErrorMessage(err), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (order) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Placed ${_formatDateTime(order.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _StatusSection(order: order),
            const SizedBox(height: AppSpacing.lg),
            Text('Items', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final item in order.items) _OrderItemRow(item: item),
            const Divider(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  formatInr(order.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
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

String _formatDateTime(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final flowIndex = _flow.indexOf(order.status);
    if (flowIndex == -1) {
      // Cancelled, returned, or a status this build doesn't recognise —
      // show it as a banner rather than a misleading timeline.
      return _StatusBanner(order: order);
    }
    return _Timeline(currentIndex: flowIndex);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;
    final isCancelled = order.status == OrderStatus.cancelled;
    final color = isCancelled ? ext.outOfStock : ext.info;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            isCancelled ? Icons.cancel_outlined : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              orderStatusLabel(order.status, order.rawStatus),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return Column(
      children: [
        for (var i = 0; i < _flow.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentIndex
                            ? theme.colorScheme.primary
                            : ext.divider,
                      ),
                      child: i <= currentIndex
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (i < _flow.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: i < currentIndex
                              ? theme.colorScheme.primary
                              : ext.divider,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      orderStatusLabel(_flow[i], ''),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: i <= currentIndex
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: SizedBox(
              width: 48,
              height: 48,
              child: CatalogImage(
                source: item.image,
                isRemote: item.hasRemoteImage,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child:
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text('× ${item.quantity}'),
          const SizedBox(width: AppSpacing.sm),
          Text(formatInr(item.totalPrice)),
        ],
      ),
    );
  }
}
