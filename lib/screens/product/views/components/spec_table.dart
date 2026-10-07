import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../models/catalog_product.dart';

/// Specifications as clean label / value rows separated by hairlines — no
/// table frame. Shows the first [initialRows] with a "Show all" toggle when
/// the list is long.
class SpecTable extends StatefulWidget {
  const SpecTable({super.key, required this.specs, this.initialRows = 5});

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: AppDurations.normal,
          curve: AppCurves.standard,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) Divider(height: 1, color: c.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.smd + 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          visible[i].label,
                          style: context.text.bodySecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 6,
                        child: Text(
                          visible[i].value,
                          style: context.text.bodyStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (collapsible) ...[
          Divider(height: 1, color: c.divider),
          InkWell(
            onTap: () => setState(() => _showAll = !_showAll),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd + 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showAll
                          ? 'Show fewer'
                          : 'Show all ${specs.length} specifications',
                      style: context.text.label.copyWith(color: c.primary),
                    ),
                  ),
                  Icon(
                    _showAll
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: AppIconSize.sm + 2,
                    color: c.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
