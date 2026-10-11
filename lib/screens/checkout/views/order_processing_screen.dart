import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_actions.dart';
import '../../order/views/order_ui.dart';
import 'payment_flow.dart';

/// Contract: poll `GET /orders/{id}` every 2–3 s, for up to 60 s.
const _pollInterval = Duration(seconds: 2, milliseconds: 500);
const _pollTimeout = Duration(seconds: 60);

/// After the sheet was closed without paying, how long to show "checking"
/// before offering Pay now / Cancel (polling carries on underneath, so a
/// decline that lands later still flips the screen to "Payment failed").
const _dismissGrace = Duration(seconds: 6);

/// What hands this screen an order after the Razorpay widget closed —
/// whichever way it closed.
class OrderProcessingArgs {
  const OrderProcessingArgs({
    required this.orderId,
    this.providerPaymentId,
    this.signature,
    this.sheetFailed = false,
    this.sheetMessage,
  });

  final String orderId;

  /// Set when the SDK's own success callback fired — null for an
  /// external-wallet handoff, which reports no payment id up front.
  final String? providerPaymentId;
  final String? signature;

  /// The SDK reported an error or the user dismissed the sheet. Not an
  /// answer: a decline becomes `PAYMENT_FAILED` via webhook within seconds,
  /// a dismissal leaves the order `PLACED` — so this screen polls either way.
  final bool sheetFailed;
  final String? sheetMessage;

  /// True when there's enough here to call `POST /payments/verify`
  /// immediately, instead of only polling.
  bool get canVerify => providerPaymentId != null && signature != null;
}

enum _Phase { verifying, placing, checking }

enum _Stage {
  /// Verifying / polling.
  working,

  /// `PAYMENT_FAILED` — retry or cancel.
  failed,

  /// Still `PLACED` after the sheet was closed — pay now or cancel.
  awaiting,

  /// `CANCELLED` (expired, or cancelled here).
  cancelled,

  /// Gave up waiting on a payment the SDK said succeeded, or an error.
  stuck,
}

/// Sits between the Razorpay widget closing and knowing what actually
/// happened. The SDK callback is never proof of payment — only the order
/// status the API returns is:
///  - on SDK success: `POST /payments/verify`, then poll while still
///    `PLACED`;
///  - on SDK error/dismissal: poll the order the same way.
///
/// `PAYMENT_FAILED` ends the poll with **Retry payment** (reopens the same
/// Razorpay order via `POST /orders/{id}/pay`, here in place) and **Cancel**.
/// The user is never sent back to checkout to retry — that would create a
/// second order while the first keeps its stock held.
class OrderProcessingScreen extends ConsumerStatefulWidget {
  const OrderProcessingScreen({super.key, required this.args});

  final OrderProcessingArgs args;

  @override
  ConsumerState<OrderProcessingScreen> createState() =>
      _OrderProcessingScreenState();
}

class _OrderProcessingScreenState extends ConsumerState<OrderProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late OrderProcessingArgs _args = widget.args;
  Order? _order;
  RefundStatus? _refund;
  _Stage _stage = _Stage.working;
  _Phase _phase = _Phase.verifying;
  String? _error;
  bool _busy = false;

  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _graceTimer;
  bool _graceElapsed = false;

  String get _orderId => _args.orderId;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _spin.dispose();
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _graceTimer?.cancel();
  }

  Future<void> _start() async {
    _stopTimers();
    setState(() {
      _stage = _Stage.working;
      _error = null;
      _phase = _args.canVerify
          ? _Phase.verifying
          : _args.sheetFailed
              ? _Phase.checking
              : _Phase.placing;
    });
    if (_args.canVerify) {
      try {
        final status = await ref.read(ordersRepositoryProvider).verifyPayment(
              orderId: _orderId,
              providerPaymentId: _args.providerPaymentId!,
              signature: _args.signature!,
            );
        // Anything but "still placed" is a real answer (CONFIRMED or
        // PAYMENT_FAILED) — fetch the full order and show it.
        if (status != OrderStatus.placed) {
          if (mounted) setState(() => _phase = _Phase.placing);
          await _fetchAndResolve();
          return;
        }
      } catch (_) {
        // A network blip, most likely — the webhook is still coming, so
        // falling back to polling recovers either way.
      }
    }
    if (!mounted) return;
    _beginPolling();
  }

  void _beginPolling() {
    _stopTimers();
    _graceElapsed = !_args.sheetFailed;
    setState(() {
      if (_stage != _Stage.awaiting) _stage = _Stage.working;
      _error = null;
      if (_phase == _Phase.verifying) _phase = _Phase.placing;
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    _timeoutTimer = Timer(_pollTimeout, _onTimeout);
    if (_args.sheetFailed) {
      _graceTimer = Timer(_dismissGrace, () {
        _graceElapsed = true;
        if (mounted &&
            _stage == _Stage.working &&
            _order?.status == OrderStatus.placed) {
          setState(() => _stage = _Stage.awaiting);
        }
      });
    }
    unawaited(_poll());
  }

  Future<void> _poll() async {
    try {
      final order = await ref.read(ordersRepositoryProvider).getOrder(_orderId);
      if (!mounted) return;
      _order = order;
      if (isTerminalForPaymentPoll(order.status)) {
        _stopTimers();
        await _resolve(order);
      } else if (_args.sheetFailed &&
          _graceElapsed &&
          _stage == _Stage.working) {
        setState(() => _stage = _Stage.awaiting);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AuthRequiredException) {
        _stopTimers();
        unawaited(
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
        );
        return;
      }
      // Keep polling (a later success still resolves); surface it now.
      if (_stage == _Stage.working) {
        setState(() {
          _error = orderErrorMessage(e);
          _stage = _Stage.stuck;
        });
      }
    }
  }

  void _onTimeout() {
    _stopTimers();
    if (!mounted) return;
    setState(() {
      _stage = _args.sheetFailed && _order?.status == OrderStatus.placed
          ? _Stage.awaiting
          : _Stage.stuck;
    });
  }

  Future<void> _fetchAndResolve() async {
    try {
      final order = await ref.read(ordersRepositoryProvider).getOrder(_orderId);
      _order = order;
      await _resolve(order);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = orderErrorMessage(e);
          _stage = _Stage.stuck;
        });
      }
    }
  }

  Future<void> _resolve(Order order) async {
    if (!mounted) return;
    switch (order.status) {
      case OrderStatus.paymentFailed:
        ref.invalidate(orderHistoryProvider);
        setState(() => _stage = _Stage.failed);
      case OrderStatus.cancelled:
        ref.invalidate(orderHistoryProvider);
        setState(() => _stage = _Stage.cancelled);
      case OrderStatus.placed:
        setState(
          () => _stage = _args.sheetFailed ? _Stage.awaiting : _Stage.stuck,
        );
      default:
        // Confirmed (or moved straight past it) — the server cart is
        // converted once payment is captured, so refresh it to match.
        unawaited(ref.read(cartControllerProvider.notifier).refresh());
        ref.invalidate(orderHistoryProvider);
        ref.invalidate(orderDetailProvider(order.id));
        unawaited(
          Navigator.pushReplacementNamed(
            context,
            thanksForOrderScreenRoute,
            arguments: order,
          ),
        );
    }
  }

  /// Retry payment / Pay now — reopens the same Razorpay order in place.
  Future<void> _pay() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sheet = await ref.read(ordersRepositoryProvider).payOrder(_orderId);
      final result = await ref.read(paymentSheetLauncherProvider)(sheet);
      if (!mounted) return;
      _args = processingArgsFor(_orderId, result);
      _busy = false;
      await _start();
    } on AuthRequiredException {
      if (!mounted) return;
      unawaited(
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.isConflict || e.isNotFound) {
        // Expired, cancelled, or already paid — show it and re-read.
        AppSnack.show(context, orderErrorMessage(e), tone: Tone.warning);
        await _fetchAndResolve();
      } else {
        AppSnack.error(context, orderErrorMessage(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(context, orderErrorMessage(e));
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final result = await cancelOrderFlow(context, ref, orderId: _orderId);
    if (!mounted) return;
    if (result != null) {
      _stopTimers();
      setState(() {
        _order = result.order;
        _refund = result.refundStatus;
        _stage = _Stage.cancelled;
      });
    }
  }

  void _viewOrder() {
    _stopTimers();
    openOrderDetailFresh(context, ref, _orderId);
  }

  void _backToCart() {
    _stopTimers();
    unawaited(ref.read(cartControllerProvider.notifier).refresh());
    ref.invalidate(orderHistoryProvider);
    resetToShellTab(context, ref, 2);
  }

  void _contactSupport() => openWhatsAppSupport(
        context,
        message: 'Hi IrriKart, my payment for order '
            '${_order == null ? _orderId : orderDisplayNumber(_order!.orderNumber)} '
            'is still processing. Can you help?',
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      // Leaving mid-verification would strand the user without a result;
      // once there's an answer (or we gave up), back goes to the order.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_stage == _Stage.working) {
          AppSnack.show(context, 'Hang on — we’re checking your payment.');
        } else {
          _viewOrder();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Scrolls only if a very short screen can't fit the content;
            // otherwise the Spacers centre it.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: AnimatedSwitcher(
                      duration: AppDurations.normal,
                      switchInCurve: AppCurves.emphasized,
                      child: switch (_stage) {
                        _Stage.working => _buildWorking(context),
                        _Stage.failed => _buildUnpaid(context, failed: true),
                        _Stage.awaiting => _buildUnpaid(context, failed: false),
                        _Stage.cancelled => _buildCancelled(context),
                        _Stage.stuck => _buildStuck(context),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorking(BuildContext context) {
    final c = context.colors;
    final title = switch (_phase) {
      _Phase.verifying => 'Confirming payment…',
      _Phase.placing => 'Placing your order…',
      _Phase.checking => 'Checking your payment…',
    };
    return Column(
      key: const ValueKey('working'),
      children: [
        const Spacer(flex: 3),
        _ProgressRing(animation: _spin),
        const SizedBox(height: AppSpacing.xl),
        AnimatedSwitcher(
          duration: AppDurations.normal,
          child: Text(
            title,
            key: ValueKey(title),
            style: context.text.h1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        Text(
          'This usually takes a few seconds.',
          style: context.text.bodySecondary,
          textAlign: TextAlign.center,
        ),
        if (_phase != _Phase.checking) ...[
          const SizedBox(height: AppSpacing.xl),
          _PhaseSteps(phase: _phase),
        ],
        const Spacer(flex: 4),
        Text(
          'Please keep the app open. Your payment is safe — we’ll take you '
          'to your order as soon as it’s confirmed.',
          style: context.text.captionMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.smd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_rounded,
              size: AppIconSize.xs,
              color: c.success,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text('Secured by Razorpay', style: context.text.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// `PAYMENT_FAILED` ([failed]) or still `PLACED` after the sheet closed.
  Widget _buildUnpaid(BuildContext context, {required bool failed}) {
    final c = context.colors;
    final order = _order;
    return Column(
      key: ValueKey(failed ? 'failed' : 'awaiting'),
      children: [
        const Spacer(flex: 3),
        _OutcomeMark(
          icon: failed
              ? Icons.credit_card_off_rounded
              : Icons.hourglass_top_rounded,
          fg: failed ? c.error : c.warning,
          bg: failed ? c.errorSoft : c.warningSoft,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          failed ? 'Payment failed' : 'Payment not completed',
          style: context.text.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.smd),
        Text(
          failed
              ? 'Your payment didn’t go through. Your items are reserved for '
                  '30 minutes from when you placed the order.'
              : 'Your order is reserved but not paid yet. Complete payment '
                  'within 30 minutes of placing it, or it will be cancelled '
                  'automatically.',
          style: context.text.bodySecondary,
          textAlign: TextAlign.center,
        ),
        if (order != null) ...[
          const SizedBox(height: AppSpacing.md),
          _WindowPill(order: order, failed: failed),
        ],
        const Spacer(flex: 4),
        if (order == null || order.canPay()) ...[
          AppButton(
            label: failed ? 'Retry payment' : 'Pay now',
            icon: Icons.lock_rounded,
            loading: _busy,
            onPressed: _pay,
          ),
          const SizedBox(height: AppSpacing.smd),
        ],
        AppButton.outline(
          label: 'Cancel order',
          onPressed: _busy ? null : _cancel,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton.ghost(label: 'View order', onPressed: _viewOrder),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildCancelled(BuildContext context) {
    final c = context.colors;
    final order = _order;
    final reason = order?.cancelReason;
    // A paid order's cart was converted at capture; an unpaid one's cart
    // was never touched, so its items are still there to re-order.
    final paid = order?.wasPaidOnline ?? false;
    final refund = _refund ?? (paid ? RefundStatus.started : null);
    return Column(
      key: const ValueKey('cancelled'),
      children: [
        const Spacer(flex: 3),
        _OutcomeMark(
          icon: Icons.cancel_rounded,
          fg: c.textSecondary,
          bg: c.surfaceSunken,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Order cancelled',
          style: context.text.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.smd),
        if (reason != null && reason.isNotEmpty) ...[
          Text(
            '“$reason”',
            style: context.text.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          paid
              ? 'Nothing more to do — you’ll get the full amount back.'
              : 'Nothing was charged. Your items are still in your cart '
                  'whenever you want to order them again.',
          style: context.text.bodySecondary,
          textAlign: TextAlign.center,
        ),
        if (refund != null && refund != RefundStatus.none) ...[
          const SizedBox(height: AppSpacing.lg),
          RefundBanner(status: refund),
        ],
        const Spacer(flex: 4),
        if (paid)
          AppButton(label: 'View order', onPressed: _viewOrder)
        else ...[
          AppButton(label: 'Back to cart', onPressed: _backToCart),
          const SizedBox(height: AppSpacing.xs),
          AppButton.ghost(label: 'View order', onPressed: _viewOrder),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildStuck(BuildContext context) {
    final c = context.colors;
    return Column(
      key: const ValueKey('stuck'),
      children: [
        const Spacer(flex: 3),
        _OutcomeMark(
          icon: Icons.hourglass_top_rounded,
          fg: c.warning,
          bg: c.warningSoft,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Still confirming your payment',
          style: context.text.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.smd),
        Text(
          _error ??
              'This is taking longer than usual. If money was debited, your '
                  'order will be confirmed automatically — check again or find '
                  'it in your orders shortly.',
          style: context.text.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Please don’t pay again for the same items until this order resolves.',
          style: context.text.caption.copyWith(color: c.warning),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 4),
        AppButton(
          label: 'Check again',
          icon: Icons.refresh_rounded,
          onPressed: _beginPolling,
        ),
        const SizedBox(height: AppSpacing.smd),
        AppButton.secondary(
          label: 'Contact support',
          icon: Icons.support_agent_rounded,
          onPressed: _contactSupport,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton.ghost(
          label: 'View order',
          onPressed: _viewOrder,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// Large soft disc with an icon — the outcome's "hero".
class _OutcomeMark extends StatelessWidget {
  const _OutcomeMark({required this.icon, required this.fg, required this.bg});

  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: AppIconSize.xl, color: fg),
    );
  }
}

/// "18:42 left to pay" — live, from `createdAt + 30 min`.
class _WindowPill extends StatelessWidget {
  const _WindowPill({required this.order, required this.failed});

  final Order order;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return TickingBuilder(
      until: order.paymentDeadline,
      builder: (context, now) {
        final left = order.paymentTimeLeft(now);
        return StatusPill(
          icon: Icons.timer_outlined,
          tone: left == Duration.zero
              ? Tone.neutral
              : failed
                  ? Tone.error
                  : Tone.warning,
          label: left == Duration.zero
              ? 'Payment window closed'
              : 'Complete payment within ${formatCountdown(left)}',
        );
      },
    );
  }
}

/// Brand progress ring: a rotating primary arc over a soft track, with a
/// gently pulsing lock badge in the middle.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.animation});

  final Animation<double> animation;

  static const _size = 136.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: _size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final pulse = 1 + 0.06 * math.sin(t * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(_size),
                painter: _RingPainter(
                  progress: t,
                  track: c.tint,
                  arc: c.accent,
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: AppIconSize.lg,
                    color: c.textOnPrimary,
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

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.arc});

  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke / 2);
    canvas.drawCircle(
      rect.center,
      deflated.width / 2,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // Arc length breathes between ~25% and ~65% as it spins.
    final sweep = math.pi * (0.5 + 0.8 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi)));
    final start = progress * 2 * math.pi - math.pi / 2;
    canvas.drawArc(
      deflated,
      start,
      sweep,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.arc != arc;
}

class _PhaseSteps extends StatelessWidget {
  const _PhaseSteps({required this.phase});

  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PhaseRow(
          label: 'Payment submitted',
          state: _RowState.done,
        ),
        _PhaseRow(
          label: 'Confirming payment',
          state: phase == _Phase.verifying ? _RowState.active : _RowState.done,
        ),
        _PhaseRow(
          label: 'Placing your order',
          state: phase == _Phase.placing ? _RowState.active : _RowState.pending,
        ),
      ],
    );
  }
}

enum _RowState { done, active, pending }

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.label, required this.state});

  final String label;
  final _RowState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Widget leading = switch (state) {
      _RowState.done =>
        Icon(Icons.check_circle_rounded, size: 18, color: c.primary),
      _RowState.active => SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
        ),
      _RowState.pending =>
        Icon(Icons.radio_button_unchecked_rounded, size: 18, color: c.textDisabled),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 18, child: Center(child: leading)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: state == _RowState.pending
                ? context.text.body.copyWith(color: c.textMuted)
                : state == _RowState.active
                    ? context.text.bodyStrong
                    : context.text.bodySecondary,
          ),
        ],
      ),
    );
  }
}
