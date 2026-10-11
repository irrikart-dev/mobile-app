import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';
import 'order_processing_screen.dart';

/// Opens the payment sheet for a checkout/pay response. A provider so tests
/// (and a future second gateway) can swap it out.
final paymentSheetLauncherProvider =
    Provider<Future<RazorpayCheckoutResult> Function(CheckoutOrder sheet)>(
  (ref) => (sheet) => openRazorpayCheckout(
        keyId: sheet.keyId,
        providerOrderId: sheet.providerOrderId,
        amountRupees: sheet.amount,
        currency: sheet.currency,
        customerId: sheet.customerId,
      ),
);

/// What the processing screen needs after the sheet closed, whichever way.
OrderProcessingArgs processingArgsFor(
  String orderId,
  RazorpayCheckoutResult result,
) =>
    switch (result.outcome) {
      RazorpayOutcome.failure => OrderProcessingArgs(
          orderId: orderId,
          sheetFailed: true,
          sheetMessage: result.message,
        ),
      _ => OrderProcessingArgs(
          orderId: orderId,
          providerPaymentId: result.paymentId,
          signature: result.signature,
        ),
    };

/// **Retry payment** / **Pay now** for an existing unpaid order: reopens the
/// same Razorpay order via `POST /orders/{id}/pay` (never a second checkout),
/// then hands over to the processing screen to verify/poll.
///
/// A `409` (expired, cancelled, or already paid) is an expected race: show
/// the server's message and refetch the order.
Future<void> retryOrderPayment(
  BuildContext context,
  WidgetRef ref,
  String orderId,
) async {
  final CheckoutOrder sheet;
  try {
    sheet = await ref.read(ordersRepositoryProvider).payOrder(orderId);
  } on AuthRequiredException {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false);
    return;
  } catch (e) {
    if (!context.mounted) return;
    _showPayError(context, ref, orderId, e);
    return;
  }

  final result = await ref.read(paymentSheetLauncherProvider)(sheet);
  if (!context.mounted) return;
  await Navigator.of(context).pushNamed(
    orderProcessingScreenRoute,
    arguments: processingArgsFor(sheet.orderId, result),
  );
  // Back here (rare — the processing screen usually moves on): show the
  // latest state.
  refetchOrder(ref, orderId);
}

void _showPayError(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  Object error,
) {
  if (error is ApiException && (error.isConflict || error.isNotFound)) {
    AppSnack.show(context, orderErrorMessage(error), tone: Tone.warning);
    refetchOrder(ref, orderId);
    return;
  }
  AppSnack.error(context, orderErrorMessage(error));
}
