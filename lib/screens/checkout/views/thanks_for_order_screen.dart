import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../route/route_constants.dart';

/// Order confirmation, shown after checkout. Matches the reference theme's
/// `order-success` screen.
class ThanksForOrderScreen extends StatelessWidget {
  const ThanksForOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;
    final orderId =
        'IRW-${100000 + DateTime.now().millisecondsSinceEpoch % 900000}';

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
                    color: ext.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.check_rounded, size: 52, color: ext.success),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Order placed!',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Order $orderId is confirmed. We will notify you as it '
                  'moves through packing and dispatch.',
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
