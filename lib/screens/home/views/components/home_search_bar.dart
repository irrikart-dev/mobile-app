import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/radius_tokens.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../../route/route_constants.dart';

/// Tappable search affordance on the Home body — not a live text field.
/// Tapping hands off to the real search screen (`SearchForm`), same pattern
/// as most grocery/e-commerce home screens: a visible, one-tap search entry
/// point rather than an app-bar icon alone.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: () => Navigator.pushNamed(context, searchScreenRoute),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Search drip kits, sprinklers, filters…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.tune,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
