import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../entry_point_tab.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';

/// Order confirmation, shown once [OrderProcessingScreen] has actually seen
/// the order leave `PLACED` — never shown purely off the Razorpay SDK
/// callback (see the checkout contract §4).
class ThanksForOrderScreen extends ConsumerStatefulWidget {
  const ThanksForOrderScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<ThanksForOrderScreen> createState() =>
      _ThanksForOrderScreenState();
}

class _ThanksForOrderScreenState extends ConsumerState<ThanksForOrderScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hero = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _hero,
    curve: const Interval(0, 0.7, curve: Curves.elasticOut),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _hero,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _hero.dispose();
    super.dispose();
  }

  Order get _order => widget.order;

  bool get _confirmed => switch (_order.status) {
        OrderStatus.confirmed ||
        OrderStatus.packed ||
        OrderStatus.shipped ||
        OrderStatus.delivered =>
          true,
        _ => false,
      };

  void _continueShopping() => resetToShellTab(context, ref, 0);

  void _viewOrder() {
    final navigator = Navigator.of(context, rootNavigator: true);
    final orderId = _order.id;
    ref.invalidate(orderHistoryProvider);
    ref.read(entryTabIndexProvider.notifier).state = 3;
    navigator.pushNamedAndRemoveUntil(entryPointScreenRoute, (_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushNamed(orderDetailsScreenRoute, arguments: orderId);
    });
  }

  Future<void> _copyNumber() async {
    await Clipboard.setData(ClipboardData(text: _order.orderNumber));
    if (mounted) AppSnack.success(context, 'Order number copied');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final order = _order;
    final address = order.address;
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final statusLabel =
        orderStatusLabel(order.status, order.rawStatus).toLowerCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continueShopping();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xxl,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            children: [
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: _SuccessMark(confirmed: _confirmed),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      _confirmed ? 'Order placed!' : 'Order $statusLabel',
                      style: context.text.display,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.smd),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        _confirmed
                            ? 'Thank you! Your payment is confirmed. We’ll let you know as soon as it’s packed and on its way.'
                            : 'Your order is now $statusLabel. Check your orders for the latest status.',
                        style: context.text.bodySecondary,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.mdPlus),
                    Material(
                      color: c.tint,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _copyNumber,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Order ',
                                style: context.text.captionMuted,
                              ),
                              Text(
                                orderDisplayNumber(order.orderNumber),
                                style: context.text.label,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                Icons.copy_rounded,
                                size: AppIconSize.xs,
                                color: c.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OverlineHeader(
                      'Items',
                      trailing: Text(
                        itemCountLabel(itemCount),
                        style: context.text.captionMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.smd),
                        child: Row(
                          children: [
                            ProductTile(image: item.image, size: 48),
                            const SizedBox(width: AppSpacing.smd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: context.text.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Qty ${item.quantity}',
                                    style: context.text.captionMuted,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              formatInr(item.totalPrice),
                              style: context.text.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                    if (address != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const Hairline(),
                      const SizedBox(height: AppSpacing.md),
                      const OverlineHeader('Delivering to'),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(address.name, style: context.text.title),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(address.oneLine, style: context.text.bodySecondary),
                      if (address.phone.isNotEmpty)
                        Text(address.phone, style: context.text.captionMuted),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.mdPlus,
                        AppSpacing.md,
                        AppSpacing.mdPlus,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _confirmed ? 'Total paid' : 'Order total',
                                  style: context.text.captionMuted,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  formatInr(order.amount),
                                  style: context.text.h2,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: AppIconSize.xs,
                                color: _confirmed ? c.success : c.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xs + 2),
                              Text(
                                _confirmed
                                    ? 'Paid via Razorpay'
                                    : 'Prepaid · Razorpay',
                                style: context.text.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: StickyFooter(
          bottom: context.bottomInset,
          child: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Keep shopping',
                  onPressed: _continueShopping,
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: AppButton(
                  label: 'View order',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: _viewOrder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big forest disc with a check, sitting in two soft sage halos.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = confirmed ? c.primary : c.warning;
    final halo = confirmed ? c.tint : c.warningSoft;
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        color: halo.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 116,
        height: 116,
        decoration: BoxDecoration(color: halo, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          child: Icon(
            confirmed ? Icons.check_rounded : Icons.hourglass_top_rounded,
            size: AppIconSize.xl,
            color: c.textOnPrimary,
          ),
        ),
      ),
    );
  }
}
