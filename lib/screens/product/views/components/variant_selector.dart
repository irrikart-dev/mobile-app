import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/catalog_product.dart';

/// Size/pack option chips. Hidden entirely when a product only has one
/// variant (most of the catalogue), so the common case stays clean.
/// Out-of-stock options stay visible but struck through and disabled.
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
    final selected = variants.where((v) => v.id == selectedId).firstOrNull;
    final prices = variants.map((v) => v.price).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('OPTION', style: context.text.overline),
            if (selected != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.label,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.smd),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final variant in variants)
              AppChip(
                // Show the price on each chip only when options differ in
                // price — otherwise it's noise.
                label: prices.length > 1
                    ? '${variant.label} · ${formatInr(variant.price)}'
                    : variant.label,
                selected: variant.id == selectedId,
                enabled: variant.buyable,
                onTap: () => onSelected(variant.id),
              ),
          ],
        ),
      ],
    );
  }
}
