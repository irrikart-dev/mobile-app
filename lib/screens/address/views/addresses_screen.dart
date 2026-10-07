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
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
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
                    0,
                    AppSpacing.gutter,
                    AppSpacing.lg,
                  ),
                  itemCount: value.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: c.divider),
                  itemBuilder: (context, i) => _AddressRow(
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

/// Canvas-coloured sticky bar; a soft upward shadow separates it from the
/// list scrolling beneath.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        boxShadow: [
          for (final s in c.shadowRaised)
            BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius,
              offset: Offset(0, -s.offset.dy / 4),
            ),
        ],
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

/// One address on the canvas: name + Default pill, phone, address, then
/// inline text actions. Rows are separated by hairlines, never boxed.
class _AddressRow extends ConsumerStatefulWidget {
  const _AddressRow({required this.address, required this.onPick});

  final Address address;

  /// Set in picker mode: tapping the row chooses it.
  final VoidCallback? onPick;

  @override
  ConsumerState<_AddressRow> createState() => _AddressRowState();
}

class _AddressRowState extends ConsumerState<_AddressRow> {
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
    // Grab the messenger context before the row may be removed (delete).
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

    final content = Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.mdPlus,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        style: context.text.h3,
                      ),
                    ),
                    if (a.isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusPill(label: 'Default', tone: Tone.primary),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_formatPhone(a.phone), style: context.text.caption),
                const SizedBox(height: AppSpacing.sm),
                Text(fullAddress, style: context.text.bodySecondary),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 40,
                  child: _busy
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.primary,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            _TextAction(label: 'Edit', onTap: _edit),
                            const _Dot(),
                            _TextAction(
                              label: 'Delete',
                              onTap: _delete,
                              color: c.textSecondary,
                            ),
                            if (!a.isDefault) ...[
                              const _Dot(),
                              _TextAction(
                                label: 'Set as default',
                                onTap: _setDefault,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (widget.onPick != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ),
        ],
      ),
    );

    if (widget.onPick == null) return content;
    return InkWell(onTap: widget.onPick, child: content);
  }
}

/// Inline text link used in the address row's action line.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xsAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.smd,
        ),
        child: Text(
          label,
          style: context.text.label.copyWith(
            color: color ?? context.colors.primary,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        '·',
        style: context.text.label.copyWith(color: context.colors.textMuted),
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
