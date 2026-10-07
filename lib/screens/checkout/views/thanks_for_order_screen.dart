import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/catalog_image.dart';
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
    final tone = _confirmed ? Tone.success : Tone.warning;
    final (fg, bg) = tone.resolve(context);
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

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
              AppSpacing.xl,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            children: [
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration:
                          BoxDecoration(color: fg, shape: BoxShape.circle),
                      child: Icon(
                        _confirmed
                            ? Icons.check_rounded
                            : Icons.hourglass_top_rounded,
                        size: 40,
                        color: c.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      _confirmed
                          ? 'Order placed!'
                          : 'Order ${orderStatusLabel(order.status, order.rawStatus).toLowerCase()}',
                      style: context.text.display,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _confirmed
                          ? 'Thank you! Your payment is confirmed and we’ll notify you as your order is packed and shipped.'
                          : 'Your order is now ${orderStatusLabel(order.status, order.rawStatus).toLowerCase()}. Check your orders for the latest status.',
                      style: context.text.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Material(
                      color: c.surface,
                      shape: StadiumBorder(side: BorderSide(color: c.border)),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _copyNumber,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Order ', style: context.text.caption),
                              Text(
                                orderDisplayNumber(order.orderNumber),
                                style: context.text.label,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                Icons.copy_rounded,
                                size: 16,
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
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      title: 'Items',
                      icon: Icons.shopping_bag_rounded,
                      trailing: Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        style: context.text.caption,
                      ),
                      child: Column(
                        children: [
                          for (final item in order.items)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.smd,
                              ),
                              child: Row(
                                children: [
                                  OrderThumb(
                                    size: 44,
                                    child: CatalogImage(
                                      source: item.image,
                                      isRemote: item.hasRemoteImage,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.smd),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: context.text.titleSm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Qty ${item.quantity}',
                                          style: context.text.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatInr(item.totalPrice),
                                    style: context.text.bodyStrong,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (address != null) ...[
                      const SizedBox(height: AppSpacing.smd),
                      SectionCard(
                        title: 'Delivering to',
                        icon: Icons.location_on_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(address.name, style: context.text.title),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              address.oneLine,
                              style: context.text.bodySecondary,
                            ),
                            if (address.phone.isNotEmpty)
                              Text(address.phone, style: context.text.caption),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.smd),
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _confirmed ? 'Total paid' : 'Order total',
                                  style: context.text.caption,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                PriceText(order.amount, large: true),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: _confirmed
                                ? 'Paid via Razorpay'
                                : 'Razorpay · prepaid',
                            tone: _confirmed ? Tone.success : Tone.neutral,
                            icon: Icons.lock_rounded,
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
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.smd,
                AppSpacing.gutter,
                AppSpacing.smd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'View order',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _viewOrder,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.outline(
                    label: 'Continue shopping',
                    onPressed: _continueShopping,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
