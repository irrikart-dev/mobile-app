import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/catalog_image.dart';
import '../../../components/ui/ui.dart';
import '../../../entry_point_tab.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';

/// Shared presentation helpers for the cart, checkout and order screens.
/// Kept in one place so a status, a product tile or a line row always reads
/// the same way.

Tone orderStatusTone(OrderStatus status) => switch (status) {
      OrderStatus.placed => Tone.warning,
      OrderStatus.paymentFailed => Tone.error,
      OrderStatus.confirmed => Tone.info,
      OrderStatus.packed || OrderStatus.shipped => Tone.primary,
      OrderStatus.delivered => Tone.success,
      OrderStatus.cancelled => Tone.error,
      OrderStatus.returned || OrderStatus.unknown => Tone.neutral,
    };

IconData orderStatusIcon(OrderStatus status) => switch (status) {
      OrderStatus.placed => Icons.schedule_rounded,
      OrderStatus.paymentFailed => Icons.credit_card_off_rounded,
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

/// `1 item` / `3 items`
String itemCountLabel(int count) => '$count ${count == 1 ? 'item' : 'items'}';

/// `24:07` — minutes and seconds left in the payment window.
String formatCountdown(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Rebuilds once a second with the current time — drives the 30-minute
/// payment countdown. [onElapsed] fires once when [until] passes.
class TickingBuilder extends StatefulWidget {
  const TickingBuilder({
    super.key,
    required this.builder,
    this.until,
    this.onElapsed,
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final DateTime? until;
  final VoidCallback? onElapsed;

  @override
  State<TickingBuilder> createState() => _TickingBuilderState();
}

class _TickingBuilderState extends State<TickingBuilder> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    final until = widget.until;
    if (!_fired && until != null && !DateTime.now().isBefore(until)) {
      _fired = true;
      widget.onElapsed?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// Resets to the Orders tab and opens [orderId]'s detail on top, freshly
/// fetched — the landing for "View order" after payment or cancellation.
void openOrderDetailFresh(BuildContext context, WidgetRef ref, String orderId) {
  final navigator = Navigator.of(context, rootNavigator: true);
  ref.invalidate(orderHistoryProvider);
  ref.invalidate(orderDetailProvider(orderId));
  ref.read(entryTabIndexProvider.notifier).state = 3;
  navigator.pushNamedAndRemoveUntil(entryPointScreenRoute, (_) => false);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigator.pushNamed(orderDetailsScreenRoute, arguments: orderId);
  });
}

/// Refetches an order (detail + list) after a `409`, so the screen matches
/// the server again.
void refetchOrder(WidgetRef ref, String orderId) {
  ref.invalidate(orderDetailProvider(orderId));
  ref.invalidate(orderHistoryProvider);
}

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

/// Square sage tile holding a product photo — the only "frame" a line item
/// gets. In light mode the photo is multiplied onto the sage so the white
/// studio backgrounds of catalogue shots melt into the tile.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.image, this.size = 76});

  /// Asset path or absolute URL (sniffed by [CatalogImage]).
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(size >= 64 ? AppRadius.md : AppRadius.sm);
    final hasImage = image != null && image!.isNotEmpty;
    // Dark mode can't multiply white onto a dark tile, so the photo simply
    // fills the tile edge to edge instead of floating as a white square.
    final dark = context.isDark;
    Widget photo = CatalogImage(
      source: image,
      fit: dark ? BoxFit.cover : BoxFit.contain,
    );
    if (hasImage && !dark) {
      photo = ColorFiltered(
        colorFilter: ColorFilter.mode(c.tint, BlendMode.multiply),
        child: photo,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.tint, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      padding: hasImage && !dark ? EdgeInsets.all(size * 0.1) : EdgeInsets.zero,
      child: hasImage
          ? photo
          : Center(
              child: Icon(
                Icons.image_rounded,
                size: size * 0.36,
                color: c.textMuted,
              ),
            ),
    );
  }
}

/// Small uppercase eyebrow over a block of content, with an optional
/// trailing action ("Change", "View all").
class OverlineHeader extends StatelessWidget {
  const OverlineHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: context.text.overline),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Low-key text action used in headers ("Change", "Show all").
class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = onTap == null ? c.textDisabled : c.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.label.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 2),
              Icon(icon, size: AppIconSize.sm, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hairline between rows, inset to the page gutter by default.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.inset = 0});

  final double inset;

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: inset,
        endIndent: inset,
        color: context.colors.divider,
      );
}

/// White sticky footer that floats over scrolled content: no top border,
/// just the raised shadow. [bottom] is the space below the content (system
/// inset, plus the floating nav when inside the tab shell).
class StickyFooter extends StatelessWidget {
  const StickyFooter({super.key, required this.child, required this.bottom});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: c.shadowRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.smd + bottom,
        ),
        child: child,
      ),
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

/// The refund outcome of a cancelled, paid order: "Refund started", or —
/// when the gateway refused — "being processed manually".
class RefundBanner extends StatelessWidget {
  const RefundBanner({super.key, required this.status});

  final RefundStatus status;

  @override
  Widget build(BuildContext context) => status == RefundStatus.failed
      ? const InlineBanner(
          tone: Tone.warning,
          title: 'Your refund is being processed manually',
          message: 'Our team will follow up and refund the full amount to '
              'your original payment method.',
        )
      : const InlineBanner(
          tone: Tone.success,
          icon: Icons.replay_rounded,
          title: 'Refund started',
          message: 'The full amount goes back to your original payment method.',
        );
}
