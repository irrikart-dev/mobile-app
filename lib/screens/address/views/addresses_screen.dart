import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/radius_tokens.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/address_data.dart';
import '../../../route/route_constants.dart';

/// Saved-address list. Doubles as a picker when [onPicked] is set — checkout
/// pushes this with a callback and pops with the chosen address instead of
/// navigating into edit, rather than a second near-duplicate list screen.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key, this.onPicked});

  final ValueChanged<Address>? onPicked;

  bool get _isPicker => onPicked != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPicker ? 'Choose delivery address' : 'Saved addresses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, addNewAddressesScreenRoute),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text('Could not load addresses: $err')),
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 72,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No saved addresses yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add a delivery address to check out.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        addNewAddressesScreenRoute,
                      ),
                      child: const Text('Add address'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxxl,
            ),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _AddressTile(
              address: addresses[i],
              onTap: _isPicker ? () => onPicked!(addresses[i]) : null,
            ),
          );
        },
      ),
    );
  }
}

class _AddressTile extends ConsumerWidget {
  const _AddressTile({required this.address, required this.onTap});

  final Address address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return InkWell(
      onTap: onTap ??
          () => Navigator.pushNamed(
                context,
                addNewAddressesScreenRoute,
                arguments: address,
              ),
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          border: Border.all(color: ext.divider),
          borderRadius: AppRadius.mdAll,
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
                      Text(address.name, style: theme.textTheme.titleSmall),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Text(
                            'Default',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address.oneLine, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    address.phone,
                    style: theme.textTheme.bodySmall?.copyWith(color: ext.muted),
                  ),
                ],
              ),
            ),
            if (onTap == null)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'default':
                      await ref
                          .read(addressControllerProvider.notifier)
                          .setDefault(address.id);
                    case 'delete':
                      await ref
                          .read(addressControllerProvider.notifier)
                          .remove(address.id);
                  }
                },
                itemBuilder: (context) => [
                  if (!address.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Text('Set as default'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
