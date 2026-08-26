import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/catalog_data.dart';
import '../../../models/order_data.dart';

/// Order detail: tracking timeline + line items + total.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = mockOrders.where((o) => o.id == orderId).firstOrNull;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final catalog = ref.watch(catalogDataProvider);

    return Scaffold(
      appBar: AppBar(title: Text(order.id)),
      body: Builder(
        builder: (context) {
          final data = catalog.valueOrNull;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('Placed ${order.date}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              _TrackingTimeline(steps: order.trackingSteps),
              const SizedBox(height: AppSpacing.lg),
              Text('Items', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final item in order.items)
                _OrderItemRow(
                  item: item,
                  productName: data?.productBySlug(item.productSlug)?.name ??
                      item.productSlug,
                  productImage: data?.productBySlug(item.productSlug)?.image,
                ),
              const Divider(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    formatInr(order.total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.steps});

  final List<OrderTrackingStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
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
                        color: steps[i].done
                            ? theme.colorScheme.primary
                            : ext.divider,
                      ),
                      child: steps[i].done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: steps[i + 1].done
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
                    child: Row(
                      children: [
                        Text(
                          steps[i].label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: steps[i].done
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (steps[i].date != null)
                          Text(steps[i].date!, style: theme.textTheme.bodySmall),
                      ],
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
  const _OrderItemRow({
    required this.item,
    required this.productName,
    this.productImage,
  });

  final OrderLineItem item;
  final String productName;
  final String? productImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: productImage != null
                ? Image.asset(productImage!, width: 48, height: 48, fit: BoxFit.cover)
                : Container(width: 48, height: 48, color: Colors.grey.shade200),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text('× ${item.qty}'),
          const SizedBox(width: AppSpacing.sm),
          Text(formatInr(item.lineTotal)),
        ],
      ),
    );
  }
}
