import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../models/address_data.dart';
import '../../../route/route_constants.dart';

/// Saved-address list. Doubles as a picker when [onPicked] is set — checkout
/// pushes this with a callback and pops with the chosen address instead of
/// navigating into edit, rather than a second near-duplicate list screen.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key, this.onPicked});

  final ValueChanged<Address>? onPicked;

  bool get _isPicker => onPicked != null;

  void _add(BuildContext context) =>
      Navigator.pushNamed(context, addNewAddressesScreenRoute);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressControllerProvider);
    final count = addressesAsync.valueOrNull?.length ?? 0;
    final hasList = addressesAsync.hasValue && count > 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppTopBar(
        title: _isPicker ? 'Choose delivery address' : 'Saved addresses',
        subtitle: hasList
            ? (count == 1 ? '1 address' : '$count addresses')
            : null,
      ),
      bottomNavigationBar: hasList
          ? _BottomBar(
              child: AppButton(
                label: 'Add new address',
                icon: Icons.add_rounded,
                onPressed: () => _add(context),
              ),
            )
          : null,
      body: switch (addressesAsync) {
        AsyncValue(:final value?, hasError: false) => value.isEmpty
            ? EmptyState(
                icon: Icons.location_on_rounded,
                title: 'No saved addresses yet',
                message: 'Add a delivery address so your pumps, pipes and '
                    'kits reach the right farm.',
                actionLabel: 'Add address',
                onAction: () => _add(context),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(addressControllerProvider.notifier).refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.lg,
                  ),
                  itemCount: value.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.smd),
                  itemBuilder: (context, i) => _AddressCard(
                    address: value[i],
                    onPick: _isPicker ? () => onPicked!(value[i]) : null,
                  ),
                ),
              ),
        AsyncValue(:final error?) => ErrorState(
            error: error,
            onRetry: () =>
                ref.read(addressControllerProvider.notifier).refresh(),
          ),
        _ => const ListSkeleton(itemCount: 3, thumb: 40),
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
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
          child: child,
        ),
      ),
    );
  }
}

class _AddressCard extends ConsumerStatefulWidget {
  const _AddressCard({required this.address, required this.onPick});

  final Address address;

  /// Set in picker mode: tapping the card chooses it.
  final VoidCallback? onPick;

  @override
  ConsumerState<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends ConsumerState<_AddressCard> {
  bool _busy = false;

  Address get _a => widget.address;

  void _edit() => Navigator.pushNamed(
        context,
        addNewAddressesScreenRoute,
        arguments: _a,
      );

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this address?',
      message: '${_a.name}, ${_a.oneLine} will be removed from your saved '
          'addresses.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(addressControllerProvider.notifier).remove(_a.id),
      success: 'Address deleted',
    );
  }

  Future<void> _setDefault() => _run(
        () => ref.read(addressControllerProvider.notifier).setDefault(_a.id),
        success: 'Default address updated',
      );

  Future<void> _run(Future<void> Function() action, {required String success}) async {
    setState(() => _busy = true);
    // Grab the messenger context before the card may be removed (delete).
    final messengerContext = Navigator.of(context).context;
    try {
      await action();
      if (messengerContext.mounted) AppSnack.success(messengerContext, success);
    } catch (e) {
      if (messengerContext.mounted) {
        AppSnack.error(messengerContext, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = _a;
    final line2 = a.line2?.trim();
    final fullAddress = [
      a.line1,
      if (line2 != null && line2.isNotEmpty) line2,
      '${a.city}, ${a.state} – ${a.pincode}',
    ].join('\n');

    return AppCard(
      onTap: widget.onPick,
      padding: EdgeInsets.zero,
      borderColor: a.isDefault ? c.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.smd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: a.isDefault ? c.primarySoft : c.surfaceSunken,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(
                    a.isDefault
                        ? Icons.home_rounded
                        : Icons.location_on_rounded,
                    size: 20,
                    color: a.isDefault ? c.onPrimarySoft : c.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.title,
                            ),
                          ),
                          if (a.isDefault) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const StatusPill(
                              label: 'Default',
                              tone: Tone.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: c.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(_formatPhone(a.phone), style: context.text.caption),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(fullAddress, style: context.text.bodySecondary),
                    ],
                  ),
                ),
                if (widget.onPick != null)
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.smd),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      AppButton.ghost(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        size: AppButtonSize.sm,
                        onPressed: _edit,
                      ),
                      AppButton.ghost(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        size: AppButtonSize.sm,
                        onPressed: _delete,
                      ),
                      const Spacer(),
                      if (!a.isDefault)
                        AppButton.ghost(
                          label: 'Set as default',
                          size: AppButtonSize.sm,
                          onPressed: _setDefault,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// "9876543210" → "+91 98765 43210"; anything else is shown as stored.
String _formatPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final local = digits.length == 12 && digits.startsWith('91')
      ? digits.substring(2)
      : digits;
  if (local.length != 10) return raw;
  return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
}
