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

  /// The SDK's own failure callback fired (sheet dismissed, card declined,
  /// timed out). Not a final answer either: a declined payment moves the
  /// order to `PAYMENT_FAILED` within seconds (via webhook), a dismissed
  /// sheet leaves it `PLACED`. Go to the order and poll — and retry with
  /// `POST /orders/{id}/pay`, never a second checkout.
  failure,
}

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult(
    this.outcome, {
    this.message,
    this.paymentId,
    this.signature,
    this.errorCode,
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

  /// Razorpay's error code on [RazorpayOutcome.failure] —
  /// [Razorpay.PAYMENT_CANCELLED] when the user closed the sheet.
  final int? errorCode;

  /// The user closed the sheet themselves (possibly after a failed attempt
  /// inside it — the SDK reports both the same way).
  bool get dismissed => errorCode == Razorpay.PAYMENT_CANCELLED;

  /// True when there is enough here to call verify. An external-wallet
  /// handoff returns no payment id, so that case still falls back to polling.
  bool get canVerify => paymentId != null && signature != null;
}

/// Opens the Razorpay payment widget for one checkout/pay sheet and resolves
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
  String? customerId,
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
        errorCode: response.code,
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
    // Lets the sheet offer this customer's saved cards/UPI IDs and save new
    // ones. Null when Razorpay was unreachable at checkout — paying still
    // works, the sheet just won't offer saving.
    if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
  });

  return completer.future;
}
