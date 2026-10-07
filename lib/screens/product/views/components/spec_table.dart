import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../models/catalog_product.dart';

/// Specifications as a bordered table with alternating row tint. Shows the
/// first [initialRows] with a "Show all" toggle when the list is long.
class SpecTable extends StatefulWidget {
  const SpecTable({super.key, required this.specs, this.initialRows = 6});

  final List<CatalogSpec> specs;
  final int initialRows;

  @override
  State<SpecTable> createState() => _SpecTableState();
}

class _SpecTableState extends State<SpecTable> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final specs = widget.specs;
    final collapsible = specs.length > widget.initialRows + 1;
    final visible = collapsible && !_showAll
        ? specs.take(widget.initialRows).toList()
        : specs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSize(
            duration: AppDurations.normal,
            curve: AppCurves.standard,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  ColoredBox(
                    color: i.isEven ? c.surfaceSunken : c.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.smd,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              visible[i].label,
                              style: context.text.bodySecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.smd),
                          Expanded(
                            flex: 3,
                            child: Text(
                              visible[i].value,
                              style: context.text.bodyStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (collapsible)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: AppButton.ghost(
              label: _showAll
                  ? 'Show fewer'
                  : 'Show all ${specs.length} specifications',
              trailingIcon: _showAll
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: AppButtonSize.sm,
              onPressed: () => setState(() => _showAll = !_showAll),
            ),
          ),
      ],
    );
  }
}
