import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';

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

class _OrderProcessingScreenState extends ConsumerState<OrderProcessingScreen> {
  Timer? _timer;
  Timer? _timeoutTimer;
  bool _timedOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
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
    // §3.1) — same items are still sitting there, ready to retry with no
    // extra work.
    unawaited(
      Navigator.pushNamedAndRemoveUntil(
        context,
        entryPointScreenRoute,
        (route) => false,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment did not go through. Your cart is unchanged — try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_timedOut && _error == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Confirming your payment…',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This usually takes a few seconds. Please don\'t close the app.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else ...[
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 56,
                    color: ext.warning,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Still processing', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error ??
                        'This is taking longer than expected. Your payment is '
                            'still being confirmed — check again, or come back '
                            'to it in your order history.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _beginPolling,
                    child: const Text('Check again'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      ordersScreenRoute,
                      (route) => false,
                    ),
                    child: const Text('View Order History'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
