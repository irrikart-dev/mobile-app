import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../components/ui/ui.dart';
import '../../../core/network/api_envelope.dart';
import '../../../models/cart_state.dart';
import '../../../models/order_data.dart';
import '../../../route/route_constants.dart';
import 'order_ui.dart';

// ---------------------------------------------------------------------------
// Cancel
// ---------------------------------------------------------------------------

/// Preset reasons offered in the cancel sheet; "Other" opens a text field.
const cancelReasonPresets = [
  'Ordered by mistake',
  'Found a better price',
  'Delivery too slow',
  'Changed my mind',
];

/// Asks for a reason, then `POST /orders/{id}/cancel`. Returns the result on
/// success (after showing the refund outcome), or null if the user backed
/// out or the server refused (a `409` is shown and the order refetched).
Future<CancelResult?> cancelOrderFlow(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
}) async {
  final outcome = await showAppSheet<_CancelOutcome>(
    context,
    title: 'Cancel this order?',
    builder: (_) => _CancelOrderSheet(orderId: orderId),
  );
  if (outcome == null || !context.mounted) return null;

  switch (outcome) {
    case _Cancelled(:final result):
      ref.read(cancelRefundStatusProvider.notifier).update(
            (m) => {...m, orderId: result.refundStatus},
          );
      refetchOrder(ref, orderId);
      AppSnack.show(
        context,
        cancelOutcomeMessage(result.refundStatus),
        tone: result.refundStatus == RefundStatus.failed
            ? Tone.warning
            : Tone.success,
        duration: const Duration(seconds: 4),
      );
      return result;
    case _Refused(:final message):
      AppSnack.show(context, message, tone: Tone.warning);
      refetchOrder(ref, orderId);
      return null;
  }
}

sealed class _CancelOutcome {
  const _CancelOutcome();
}

class _Cancelled extends _CancelOutcome {
  const _Cancelled(this.result);
  final CancelResult result;
}

/// `409`/`404` — the order changed under us (packed, expired, gone).
class _Refused extends _CancelOutcome {
  const _Refused(this.message);
  final String message;
}

class _CancelOrderSheet extends ConsumerStatefulWidget {
  const _CancelOrderSheet({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends ConsumerState<_CancelOrderSheet> {
  static const _other = 'Other';

  final _otherController = TextEditingController();
  String? _choice;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String get _reason =>
      _choice == _other ? _otherController.text.trim() : (_choice ?? '');

  bool get _valid => _reason.length >= 3 && _reason.length <= 500;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(ordersRepositoryProvider)
          .cancelOrder(widget.orderId, _reason);
      if (mounted) Navigator.pop(context, _Cancelled(result));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict || e.isNotFound) {
        Navigator.pop(context, _Refused(orderErrorMessage(e)));
      } else {
        setState(() {
          _busy = false;
          _error = orderErrorMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = orderErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tell us why — it helps us improve. Any amount paid is refunded '
          'in full to your original payment method.',
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final reason in [...cancelReasonPresets, _other])
          ReasonRow(
            label: reason,
            selected: _choice == reason,
            onTap: _busy ? null : () => setState(() => _choice = reason),
          ),
        if (_choice == _other) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Your reason',
            hint: 'At least 3 characters',
            controller: _otherController,
            maxLines: 3,
            maxLength: 500,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.smd),
          InlineBanner(message: _error!, tone: Tone.error),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Cancel order',
          variant: AppButtonVariant.destructive,
          loading: _busy,
          onPressed: _valid ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: AppButton.ghost(
            label: 'Keep my order',
            onPressed: _busy ? null : () => Navigator.maybePop(context),
          ),
        ),
      ],
    );
  }
}

/// Flat radio row — no box, just the control and the label. Shared by the
/// cancel and return forms.
class ReasonRow extends StatelessWidget {
  const ReasonRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? c.primary : c.textMuted,
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Text(
                label,
                style: selected ? context.text.bodyStrong : context.text.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reorder
// ---------------------------------------------------------------------------

/// `POST /orders/{id}/reorder`: puts the order's lines back in the cart,
/// refreshes the cart, explains any lines that couldn't be added, then opens
/// the cart. [items] are the order's lines, used to name skipped variants.
Future<void> reorderFlow(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required List<OrderItem> items,
}) async {
  final ReorderResult result;
  try {
    result = await ref.read(ordersRepositoryProvider).reorder(orderId);
  } on AuthRequiredException {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false);
    return;
  } catch (e) {
    if (!context.mounted) return;
    if (e is ApiException && e.isConflict) {
      // e.g. the cart holds another seller's items.
      AppSnack.show(context, orderErrorMessage(e), tone: Tone.warning);
      await ref.read(cartControllerProvider.notifier).refresh();
    } else {
      AppSnack.error(context, orderErrorMessage(e));
    }
    return;
  }

  await ref.read(cartControllerProvider.notifier).refresh();
  if (!context.mounted) return;

  final allSkipped = result.skipped.length >= items.length && items.isNotEmpty;
  if (result.skipped.isNotEmpty) {
    await showAppSheet<void>(
      context,
      title: allSkipped
          ? 'Couldn’t add these items'
          : 'Some items couldn’t be added',
      builder: (sheetContext) => _SkippedSheet(
        skipped: result.skipped,
        items: items,
        allSkipped: allSkipped,
      ),
    );
    if (!context.mounted) return;
  }
  if (allSkipped) return;
  if (result.skipped.isEmpty) AppSnack.success(context, 'Added to your cart');
  await Navigator.of(context).pushNamed(cartScreenRoute);
}

class _SkippedSheet extends StatelessWidget {
  const _SkippedSheet({
    required this.skipped,
    required this.items,
    required this.allSkipped,
  });

  final List<SkippedLine> skipped;
  final List<OrderItem> items;
  final bool allSkipped;

  @override
  Widget build(BuildContext context) {
    final byVariant = {for (final i in items) i.variantId: i};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          allSkipped
              ? 'None of this order’s items can be added to your cart right now.'
              : 'Everything else from this order is in your cart.',
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < skipped.length; i++) ...[
          if (i > 0) const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
            child: Row(
              children: [
                ProductTile(image: byVariant[skipped[i].variantId]?.image, size: 48),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        byVariant[skipped[i].variantId]?.name ?? 'An item',
                        style: context.text.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        skipped[i].reason,
                        style: context.text.caption
                            .copyWith(color: context.colors.warning),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: allSkipped ? 'OK' : 'Go to cart',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Invoice
// ---------------------------------------------------------------------------

/// Downloads `GET /orders/{id}/invoice` with the app's authenticated client,
/// saves it as `invoice-<orderNumber>.pdf` in the temp directory and opens
/// the share sheet (from which it can be viewed, saved or sent). A plain URL
/// can't be used — the endpoint needs the auth header.
Future<void> downloadInvoiceFlow(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required String orderNumber,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    final bytes =
        await ref.read(ordersRepositoryProvider).downloadInvoice(orderId);
    final dir = await getTemporaryDirectory();
    final safe = orderNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File('${dir.path}/invoice-$safe.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: 'invoice-$safe.pdf')],
      subject: 'IrriKart invoice ${orderDisplayNumber(orderNumber)}',
      sharePositionOrigin: origin,
    );
  } on AuthRequiredException {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (e.isConflict) {
      AppSnack.show(context, orderErrorMessage(e), tone: Tone.warning);
      refetchOrder(ref, orderId);
    } else {
      AppSnack.error(context, orderErrorMessage(e));
    }
  } catch (_) {
    if (context.mounted) {
      AppSnack.error(context, 'Couldn’t open the invoice. Please try again.');
    }
  }
}
