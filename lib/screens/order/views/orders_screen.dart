import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/shadow_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';

/// Orders tab. Matches the reference theme's `orders-screen`: a list of
/// order cards (order number, date, status pill, total) opening the order
/// detail on tap. Newest first, capped at 50 by the backend — no pagination.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        automaticallyImplyLeading: false,
      ),
      body: ordersAsync.when(
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
                  onPressed: () => ref.invalidate(orderHistoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (orders) => orders.isEmpty
            ? Center(
                child: Text(
                  "You haven't placed any orders yet.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(orderHistoryProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _OrderCard(order: orders[i]),
                ),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: () => Navigator.pushNamed(
        context,
        orderDetailsScreenRoute,
        arguments: order.id,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        _formatDate(order.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: order.status, rawStatus: order.rawStatus),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Text(
              formatInr(order.amount),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.rawStatus});

  final OrderStatus status;
  final String rawStatus;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorsExt>()!;
    final color = switch (status) {
      OrderStatus.delivered => ext.success,
      OrderStatus.confirmed || OrderStatus.shipped => ext.info,
      OrderStatus.placed || OrderStatus.packed => ext.warning,
      OrderStatus.cancelled || OrderStatus.returned => ext.outOfStock,
      OrderStatus.unknown => ext.muted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        orderStatusLabel(status, rawStatus),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
