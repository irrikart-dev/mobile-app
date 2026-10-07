import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';

const _pollInterval = Duration(seconds: 2, milliseconds: 500);
const _pollTimeout = Duration(seconds: 30);

/// What the checkout screen hands this screen after the Razorpay widget
/// closes with a result worth chasing.
class OrderProcessingArgs {
  const OrderProcessingArgs({
    required this.orderId,
    this.providerPaymentId,
    this.signature,
  });

  final String orderId;

  /// Set when the SDK's own success callback fired — null for an
  /// external-wallet handoff, which reports no payment id up front.
  final String? providerPaymentId;
  final String? signature;

  /// True when there's enough here to call `POST /payments/verify`
  /// immediately, instead of only polling.
  bool get canVerify => providerPaymentId != null && signature != null;
}

enum _Phase { verifying, placing }

/// Sits between the Razorpay widget closing and knowing what actually
/// happened. Per the checkout contract §4, the SDK's success callback only
/// means "payment probably went through" — an order isn't truly confirmed
/// until either:
///  - this screen calls `POST /payments/verify` itself (the common path —
///    resolves in about one round trip, doesn't wait on Razorpay's webhook), or
///  - Razorpay's webhook reaches the backend first and flips the status
///    (covers an external-wallet handoff, or verify failing on a network blip).
///
/// [_beginPolling] is the fallback for both of those cases, and gives up
/// after 30s with a "still processing" message and a way to check again,
/// rather than spinning forever — the order resolves eventually either way.
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

  Timer? _timer;
  Timer? _timeoutTimer;
  bool _timedOut = false;
  String? _error;
  _Phase _phase = _Phase.verifying;

  bool get _stuck => _timedOut || _error != null;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _spin.dispose();
    _timer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.args.canVerify) {
      try {
        final status = await ref.read(ordersRepositoryProvider).verifyPayment(
              orderId: widget.args.orderId,
              providerPaymentId: widget.args.providerPaymentId!,
              signature: widget.args.signature!,
            );
        // Anything other than "still placed" is a real answer — no need to
        // poll for it. Still placed just means the gateway hadn't captured
        // it at the moment of the call; fall through to polling for that.
        if (status != OrderStatus.placed) {
          if (mounted) setState(() => _phase = _Phase.placing);
          await _resolveStatus(status);
          return;
        }
      } catch (_) {
        // Verify itself failed (network blip, since a bad signature/order
        // mismatch would be a real bug, not something to silently swallow —
        // but either way the webhook is still coming, so falling back to
        // polling recovers cleanly regardless of why this failed).
      }
    }
    if (!mounted) return;
    _beginPolling();
  }

  void _beginPolling() {
    setState(() {
      _timedOut = false;
      _error = null;
      _phase = _Phase.placing;
    });
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_pollTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_timedOut) return;
    try {
      final order = await ref
          .read(ordersRepositoryProvider)
          .getOrder(widget.args.orderId);
      if (!mounted || order.status == OrderStatus.placed) return;
      _timer?.cancel();
      _timeoutTimer?.cancel();
      await _showResult(order);
    } catch (e) {
      if (mounted) setState(() => _error = orderErrorMessage(e));
    }
  }

  /// The verify path only gets a bare status back (see
  /// `OrdersRepository.verifyPayment`) — fetch the full order before showing
  /// anything, same as the polling path always has.
  Future<void> _resolveStatus(OrderStatus status) async {
    if (status == OrderStatus.cancelled) {
      _showCancelled();
      return;
    }
    try {
      final order = await ref
          .read(ordersRepositoryProvider)
          .getOrder(widget.args.orderId);
      await _showResult(order);
    } catch (e) {
      if (mounted) setState(() => _error = orderErrorMessage(e));
    }
  }

  Future<void> _showResult(Order order) async {
    if (order.status == OrderStatus.cancelled) {
      _showCancelled();
      return;
    }
    // Confirmed (or moved straight past it) — the cart converts server-side
    // once payment is captured, so refresh the local cart state to match.
    unawaited(ref.read(cartControllerProvider.notifier).refresh());
    ref.invalidate(orderHistoryProvider);
    if (!mounted) return;
    unawaited(
      Navigator.pushReplacementNamed(
        context,
        thanksForOrderScreenRoute,
        arguments: order,
      ),
    );
  }

  void _showCancelled() {
    if (!mounted) return;
    // Stock was released and the cart was never touched (checkout contract
    // §3.1) — same items are still sitting in the cart, ready to retry.
    AppSnack.show(
      context,
      'Payment did not go through. Your cart is unchanged — try again.',
      tone: Tone.warning,
    );
    resetToShellTab(context, ref, 2);
  }

  void _viewOrders() {
    _timer?.cancel();
    _timeoutTimer?.cancel();
    ref.invalidate(orderHistoryProvider);
    resetToShellTab(context, ref, 3);
  }

  void _contactSupport() => openWhatsAppSupport(
        context,
        message:
            'Hi IrriKart, my payment for order ${widget.args.orderId} is still processing. Can you help?',
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      // Leaving mid-verification would strand the user without a result;
      // once we've given up waiting, back is fine (goes to order history).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_stuck) {
          _viewOrders();
        } else {
          AppSnack.show(
            context,
            'Hang on — we’re confirming your payment.',
          );
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
                      child: _stuck
                          ? _buildStuck(context)
                          : _buildWorking(context),
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
            style: context.text.h2,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This usually takes a few seconds.',
          style: context.text.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        _PhaseSteps(phase: _phase),
        const Spacer(flex: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            children: [
              Icon(Icons.phonelink_lock_rounded, size: 20, color: c.textSecondary),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Text(
                  'Don’t close the app or press back. Your payment is safe — '
                  'we’ll take you to your order as soon as it’s confirmed.',
                  style: context.text.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 13, color: c.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Text('Secured by Razorpay', style: context.text.captionMuted),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildStuck(BuildContext context) {
    final c = context.colors;
    return Column(
      key: const ValueKey('stuck'),
      children: [
        const Spacer(flex: 3),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: c.warningSoft, shape: BoxShape.circle),
          child: Icon(Icons.hourglass_top_rounded, size: 44, color: c.warning),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Still confirming your payment',
          style: context.text.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _error ??
              'This is taking longer than usual. If money was debited, your '
                  'order will be confirmed automatically — check again or find '
                  'it in your orders shortly.',
          style: context.text.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        const InlineBanner(
          tone: Tone.info,
          message:
              'Please don’t pay again for the same items until this order resolves.',
        ),
        const Spacer(flex: 4),
        AppButton(
          label: 'Check again',
          icon: Icons.refresh_rounded,
          onPressed: _beginPolling,
        ),
        const SizedBox(height: AppSpacing.smd),
        AppButton.outline(
          label: 'Contact support',
          icon: Icons.support_agent_rounded,
          onPressed: _contactSupport,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton.ghost(
          label: 'View my orders',
          onPressed: _viewOrders,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// Brand progress ring: a rotating primary arc over a soft track, with a
/// gently pulsing lock badge in the middle.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.animation});

  final Animation<double> animation;

  static const _size = 120.0;

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
                  track: c.primarySoft,
                  arc: c.primary,
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 30,
                    color: c.onPrimarySoft,
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
        Icon(Icons.check_circle_rounded, size: 18, color: c.success),
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
