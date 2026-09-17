import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// How the Razorpay widget's callback finished — **not** whether the order
/// is confirmed. Per the checkout contract §4, even [success] only means
/// "Razorpay accepted the payment client-side"; real confirmation comes from
/// polling the order status afterward (`orderProcessingScreenRoute`).
enum RazorpayOutcome {
  /// The SDK's own success callback fired. Still needs polling to confirm.
  success,

  /// The user finished via an external wallet app — Razorpay hands control
  /// back before it knows the outcome. Also needs polling.
  externalWallet,

  /// The SDK's own failure callback fired (cancelled, card declined,
  /// timed out). The order the checkout call created will resolve to
  /// `CANCELLED` on its own via the webhook; the cart is untouched, so
  /// retrying checkout immediately is safe.
  failure,
}

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult(
    this.outcome, {
    this.message,
    this.paymentId,
    this.signature,
  });

  final RazorpayOutcome outcome;

  /// Set on [RazorpayOutcome.failure] (a message safe to show) and on
  /// [RazorpayOutcome.externalWallet] (which wallet). Null on
  /// [RazorpayOutcome.success].
  final String? message;

  /// Set on [RazorpayOutcome.success]. Together these are the handshake the
  /// backend's `POST /payments/verify` needs to confirm the order without
  /// waiting for Razorpay's webhook — the signature proves this device
  /// actually made the payment it's claiming.
  final String? paymentId;
  final String? signature;

  /// True when there is enough here to call verify. An external-wallet
  /// handoff returns no payment id, so that case still falls back to polling.
  bool get canVerify => paymentId != null && signature != null;
}

/// Opens the Razorpay payment widget for one [CheckoutOrder] and resolves
/// once the user has finished with it one way or another.
///
/// `razorpay_flutter`'s API is callback-based (`Razorpay.on(...)`), not
/// `Future`-based — this wraps it in a `Completer` so call sites can
/// `await` it like everything else in this app talks to the network.
Future<RazorpayCheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String providerOrderId,
  required num amountRupees,
  required String currency,
  String name = 'IrriKart',
}) {
  final razorpay = Razorpay();
  final completer = Completer<RazorpayCheckoutResult>();

  void finish(RazorpayCheckoutResult result) {
    if (!completer.isCompleted) completer.complete(result);
    razorpay.clear();
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
      (PaymentSuccessResponse response) {
    finish(
      RazorpayCheckoutResult(
        RazorpayOutcome.success,
        paymentId: response.paymentId,
        signature: response.signature,
      ),
    );
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    finish(
      RazorpayCheckoutResult(
        RazorpayOutcome.failure,
        message: response.message ?? 'Payment failed. Please try again.',
      ),
    );
  });

  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
      (ExternalWalletResponse response) {
    finish(
      RazorpayCheckoutResult(
        RazorpayOutcome.externalWallet,
        message: response.walletName,
      ),
    );
  });

  razorpay.open({
    'key': keyId,
    'order_id': providerOrderId,
    // Paise — the one place the app deals in paise, per the contract.
    'amount': (amountRupees * 100).round(),
    'currency': currency,
    'name': name,
  });

  return completer.future;
}
