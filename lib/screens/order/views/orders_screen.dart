import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/shadow_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';

/// Orders tab. Matches the reference theme's `orders-screen`: a list of
/// order cards (id, date, status pill, item count, total) opening the order
/// detail on tap.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        automaticallyImplyLeading: false,
      ),
      body: mockOrders.isEmpty
          ? Center(
              child: Text(
                "You haven't placed any orders yet.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: mockOrders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _OrderCard(order: mockOrders[i]),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final MockOrder order;

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
                      Text(order.id, style: theme.textTheme.titleSmall),
                      Text(order.date, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusPill(status: order.status),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Text(
              '${order.items.length} item${order.items.length == 1 ? '' : 's'}'
              '${order.eta != null ? ' · ${order.eta}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              formatInr(order.total),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorsExt>()!;
    final color = switch (status) {
      OrderStatus.delivered => ext.success,
      OrderStatus.shipped => ext.info,
      OrderStatus.processing || OrderStatus.packed => ext.warning,
      OrderStatus.cancelled => ext.outOfStock,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        status.label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
