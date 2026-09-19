import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/radius_tokens.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../../models/catalog_product.dart';

/// Size/pack option chips. Hidden entirely when a product only has one
/// variant — most of the catalogue — so this never adds noise to the common
/// case.
class VariantSelector extends StatelessWidget {
  const VariantSelector({
    super.key,
    required this.variants,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CatalogVariant> variants;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (variants.length <= 1) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Options', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final variant in variants)
                ChoiceChip(
                  label: Text(variant.label),
                  selected: variant.id == selectedId,
                  onSelected: variant.buyable
                      ? (_) => onSelected(variant.id)
                      : null,
                  disabledColor:
                      theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  labelStyle: TextStyle(
                    decoration: variant.buyable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillAll,
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
