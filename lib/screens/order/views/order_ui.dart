import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/ui/ui.dart';
import '../../../entry_point_tab.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';

/// Shared presentation helpers for order screens (orders list, detail,
/// confirmation). Kept in one place so a status always reads the same way.

Tone orderStatusTone(OrderStatus status) => switch (status) {
      OrderStatus.placed || OrderStatus.confirmed => Tone.info,
      OrderStatus.packed || OrderStatus.shipped => Tone.primary,
      OrderStatus.delivered => Tone.success,
      OrderStatus.cancelled => Tone.error,
      OrderStatus.returned || OrderStatus.unknown => Tone.neutral,
    };

IconData orderStatusIcon(OrderStatus status) => switch (status) {
      OrderStatus.placed => Icons.receipt_long_rounded,
      OrderStatus.confirmed => Icons.verified_rounded,
      OrderStatus.packed => Icons.inventory_2_rounded,
      OrderStatus.shipped => Icons.local_shipping_rounded,
      OrderStatus.delivered => Icons.home_rounded,
      OrderStatus.cancelled => Icons.cancel_rounded,
      OrderStatus.returned => Icons.assignment_return_rounded,
      OrderStatus.unknown => Icons.help_outline_rounded,
    };

/// `#IK-1042` — adds the hash only when the backend number lacks one.
String orderDisplayNumber(String orderNumber) =>
    orderNumber.startsWith('#') ? orderNumber : '#$orderNumber';

/// `7 Oct 2026`
String formatOrderDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// `7 Oct 2026, 3:45 PM`
String formatOrderDateTime(DateTime date) =>
    DateFormat('d MMM yyyy, h:mm a').format(date);

/// Switches the tab shell to [tab]. When the calling screen was pushed on
/// top of the shell (e.g. Cart via `cartScreenRoute`), pops back to it first.
void goToShellTab(BuildContext context, WidgetRef ref, int tab) {
  ref.read(entryTabIndexProvider.notifier).state = tab;
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil(
      (route) => route.settings.name == entryPointScreenRoute || route.isFirst,
    );
  }
}

/// Clears the stack back to a fresh tab shell on [tab].
void resetToShellTab(BuildContext context, WidgetRef ref, int tab) {
  ref.read(entryTabIndexProvider.notifier).state = tab;
  Navigator.of(context, rootNavigator: true)
      .pushNamedAndRemoveUntil(entryPointScreenRoute, (_) => false);
}

/// Small rounded thumbnail frame used for product images in order rows.
class OrderThumb extends StatelessWidget {
  const OrderThumb({super.key, required this.child, this.size = 56});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Lets a centered state view (empty/filtered-out) still be pulled to
/// refresh.
class RefreshableFill extends StatelessWidget {
  const RefreshableFill({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      ),
    );
  }
}
