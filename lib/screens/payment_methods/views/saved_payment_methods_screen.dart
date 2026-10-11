import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/payments/saved_payment_methods.dart';
import '../../../models/order_data.dart' show orderErrorMessage;
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';

/// Account › Saved payment methods: cards, UPI IDs, wallets and banks the
/// user chose to save inside the Razorpay sheet. List + remove only —
/// saving itself happens in the payment sheet at checkout.
class SavedPaymentMethodsScreen extends ConsumerStatefulWidget {
  const SavedPaymentMethodsScreen({super.key});

  @override
  ConsumerState<SavedPaymentMethodsScreen> createState() =>
      _SavedPaymentMethodsScreenState();
}

class _SavedPaymentMethodsScreenState
    extends ConsumerState<SavedPaymentMethodsScreen> {
  final _removing = <String>{};

  Future<void> _refresh() async {
    ref.invalidate(savedPaymentMethodsProvider);
    try {
      await ref.read(savedPaymentMethodsProvider.future);
    } catch (_) {
      // Shown by the error branch.
    }
  }

  Future<void> _remove(SavedPaymentMethod method) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${method.title}?',
      message: 'You can save it again the next time you pay.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _removing.add(method.id));
    try {
      await ref.read(savedPaymentMethodsRepositoryProvider).delete(method.id);
      if (mounted) AppSnack.success(context, 'Payment method removed');
    } on AuthRequiredException {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false);
      return;
    } on ApiException catch (e) {
      // 404: already gone — the refetch below shows the truth.
      if (mounted && !e.isNotFound) AppSnack.error(context, orderErrorMessage(e));
    } catch (e) {
      if (mounted) AppSnack.error(context, orderErrorMessage(e));
    }
    if (!mounted) return;
    ref.invalidate(savedPaymentMethodsProvider);
    try {
      await ref.read(savedPaymentMethodsProvider.future);
    } catch (_) {}
    if (mounted) setState(() => _removing.remove(method.id));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Saved payment methods'),
      body: !signedIn
          ? EmptyState(
              icon: Icons.lock_rounded,
              title: 'Sign in to see saved payment methods',
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, logInScreenRoute),
            )
          : ref.watch(savedPaymentMethodsProvider).when(
                skipLoadingOnRefresh: true,
                loading: () => const ListSkeleton(thumb: 44, itemCount: 3),
                error: (err, _) => err is AuthRequiredException
                    ? EmptyState(
                        icon: Icons.lock_rounded,
                        title: 'Sign in to see saved payment methods',
                        message: orderErrorMessage(err),
                        actionLabel: 'Sign in',
                        onAction: () => Navigator.of(context, rootNavigator: true)
                            .pushNamedAndRemoveUntil(
                          logInScreenRoute,
                          (_) => false,
                        ),
                      )
                    : ErrorState(
                        error: err,
                        message: orderErrorMessage(err),
                        onRetry: () =>
                            ref.invalidate(savedPaymentMethodsProvider),
                      ),
                data: (methods) => methods.isEmpty
                    ? RefreshableFill(
                        onRefresh: _refresh,
                        child: const EmptyState(
                          icon: Icons.credit_card_rounded,
                          title: 'No saved payment methods',
                          message: 'When you pay, you can save a card or UPI '
                              'ID in the payment window for faster checkout. '
                              'It will show up here.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        color: c.primary,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: AppSpacing.xs,
                            bottom: AppSpacing.xl + context.bottomInset,
                          ),
                          children: [
                            for (var i = 0; i < methods.length; i++) ...[
                              if (i > 0)
                                const Hairline(inset: AppSpacing.gutter),
                              _MethodRow(
                                method: methods[i],
                                removing: _removing.contains(methods[i].id),
                                onRemove: () => _remove(methods[i]),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.gutter,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: AppIconSize.xs,
                                    color: c.success,
                                  ),
                                  const SizedBox(width: AppSpacing.xs + 2),
                                  Expanded(
                                    child: Text(
                                      'Saved securely with Razorpay. IrriKart '
                                      'never stores your full card number. '
                                      'Add new methods by choosing “save” '
                                      'when you pay.',
                                      style: context.text.captionMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
    );
  }
}

IconData _methodIcon(String method) => switch (method) {
      'card' => Icons.credit_card_rounded,
      'upi' => Icons.qr_code_2_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      'netbanking' => Icons.account_balance_rounded,
      _ => Icons.payments_rounded,
    };

/// One saved method as a flat row: sage icon tile, title + kind, remove.
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.removing,
    required this.onRemove,
  });

  final SavedPaymentMethod method;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.smd,
        AppSpacing.sm,
        AppSpacing.smd,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.tint, borderRadius: AppRadius.mdAll),
            child: Icon(
              _methodIcon(method.method),
              size: AppIconSize.md,
              color: c.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.smd + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.title,
                  style: context.text.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(method.subtitle, style: context.text.captionMuted),
              ],
            ),
          ),
          if (removing)
            SizedBox.square(
              dimension: 44,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
              ),
            )
          else
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove',
              color: c.textSecondary,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
