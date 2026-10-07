import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../models/cart_state.dart' show AuthRequiredException;
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import 'order_ui.dart';

enum _OrderFilter {
  all('All'),
  active('Active'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const _OrderFilter(this.label);
  final String label;

  bool matches(OrderStatus s) => switch (this) {
        _OrderFilter.all => true,
        _OrderFilter.active => switch (s) {
            OrderStatus.placed ||
            OrderStatus.confirmed ||
            OrderStatus.packed ||
            OrderStatus.shipped ||
            OrderStatus.unknown =>
              true,
            _ => false,
          },
        _OrderFilter.delivered => s == OrderStatus.delivered,
        _OrderFilter.cancelled =>
          s == OrderStatus.cancelled || s == OrderStatus.returned,
      };
}

/// Orders. A tab root in the shell, also pushable via `ordersScreenRoute`.
/// Newest first, capped at 50 by the backend — no pagination.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  _OrderFilter _filter = _OrderFilter.all;

  Future<void> _refresh() async {
    try {
      ref.invalidate(orderHistoryProvider);
      await ref.read(orderHistoryProvider.future);
    } catch (_) {
      // Shown by the error branch.
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    final c = context.colors;

    if (!signedIn) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: const AppTopBar(large: true, title: 'Orders'),
        body: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Sign in to see your orders',
          message: 'Track every order from payment to delivery.',
          actionLabel: 'Sign in',
          onAction: () => Navigator.pushNamed(context, logInScreenRoute),
        ),
      );
    }

    final ordersAsync = ref.watch(orderHistoryProvider);
    final count = ordersAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(
        large: true,
        title: 'Orders',
        subtitle: count > 0 ? '$count ${count == 1 ? 'order' : 'orders'}' : null,
      ),
      body: ordersAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const ListSkeleton(thumb: 44),
        error: (err, _) => err is AuthRequiredException
            ? EmptyState(
                icon: Icons.lock_rounded,
                title: 'Sign in to see your orders',
                message: orderErrorMessage(err),
                actionLabel: 'Sign in',
                onAction: () => Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
              )
            : ErrorState(
                error: err,
                message: orderErrorMessage(err),
                onRetry: () => ref.invalidate(orderHistoryProvider),
              ),
        data: (orders) {
          if (orders.isEmpty) {
            return RefreshableFill(
              onRefresh: _refresh,
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No orders yet',
                message:
                    'When you place an order, you can track it here from payment to delivery.',
                actionLabel: 'Start shopping',
                onAction: () => goToShellTab(context, ref, 0),
              ),
            );
          }
          final visible =
              orders.where((o) => _filter.matches(o.status)).toList();
          return Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              ChipRow(
                children: [
                  for (final f in _OrderFilter.values)
                    AppChip(
                      label: f.label,
                      selected: f == _filter,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.smd),
              Expanded(
                child: visible.isEmpty
                    ? RefreshableFill(
                        onRefresh: _refresh,
                        child: EmptyState(
                          compact: true,
                          icon: Icons.filter_list_rounded,
                          title: 'No ${_filter.label.toLowerCase()} orders',
                          message: 'Try another filter to see more orders.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        color: c.primary,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            // viewPadding: the shell's extendBody already
                            // folds the nav into MediaQuery.padding.
                            bottom: AppSpacing.fabClearance +
                                MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const Hairline(inset: AppSpacing.gutter),
                          itemBuilder: (context, i) =>
                              _OrderRow(order: visible[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One order as a flat row: sage status tile, number + date, then total and
/// status pill on the right. Rows are split by hairlines, not boxed.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = orderStatusTone(order.status);

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        orderDetailsScreenRoute,
        arguments: order.id,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.tint,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                orderStatusIcon(order.status),
                size: AppIconSize.md,
                color: c.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.smd + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatOrderDate(order.createdAt),
                    style: context.text.captionMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Order ${orderDisplayNumber(order.orderNumber)}',
                    style: context.text.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PriceText(order.amount),
                const SizedBox(height: AppSpacing.xs + 2),
                StatusPill(
                  label: orderStatusLabel(order.status, order.rawStatus),
                  tone: tone,
                  dot: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
