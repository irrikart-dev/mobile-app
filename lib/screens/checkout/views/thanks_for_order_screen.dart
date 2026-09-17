import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';

/// Order confirmation, shown once [OrderProcessingScreen]'s polling has
/// actually seen the order leave `PLACED` — never shown purely off the
/// Razorpay SDK callback (see the checkout contract §4).
class ThanksForOrderScreen extends StatelessWidget {
  const ThanksForOrderScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;
    final confirmed = order.status == OrderStatus.confirmed;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    color: (confirmed ? ext.success : ext.warning)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    confirmed
                        ? Icons.check_rounded
                        : Icons.hourglass_top_rounded,
                    size: 52,
                    color: confirmed ? ext.success : ext.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  confirmed
                      ? 'Order placed!'
                      : 'Order ${order.rawStatus.toLowerCase()}',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  confirmed
                      ? 'Order ${order.orderNumber} is confirmed — ${formatInr(order.amount)} '
                          'charged. We will notify you as it moves through packing and dispatch.'
                      : 'Order ${order.orderNumber} is now ${orderStatusLabel(order.status, order.rawStatus).toLowerCase()}. '
                          'Check your order history for the latest status.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      ordersScreenRoute,
                      (route) => false,
                    ),
                    child: const Text('View Order'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      entryPointScreenRoute,
                      (route) => false,
                    ),
                    child: const Text('Continue Shopping'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
