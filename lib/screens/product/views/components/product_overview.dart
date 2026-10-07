import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Key highlights (first few features as check rows) followed by the
/// description, collapsed to a few lines with a "Read more" toggle.
class ProductOverview extends StatefulWidget {
  const ProductOverview({
    super.key,
    required this.features,
    required this.description,
  });

  final List<String> features;
  final String description;

  static const int maxHighlights = 5;
  static const int collapsedLines = 4;

  @override
  State<ProductOverview> createState() => _ProductOverviewState();
}

class _ProductOverviewState extends State<ProductOverview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final highlights =
        widget.features.take(ProductOverview.maxHighlights).toList();
    final description = widget.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (highlights.isNotEmpty) ...[
          Text('Highlights', style: context.text.h3),
          const SizedBox(height: AppSpacing.smd),
          for (final feature in highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.smd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: c.onPrimarySoft,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(child: Text(feature, style: context.text.body)),
                ],
              ),
            ),
        ],
        if (description.isNotEmpty) ...[
          if (highlights.isNotEmpty) const SizedBox(height: AppSpacing.md),
          Text('About this product', style: context.text.h3),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final style = context.text.bodySecondary;
              final painter = TextPainter(
                text: TextSpan(text: description, style: style),
                maxLines: ProductOverview.collapsedLines,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final overflows = painter.didExceedMaxLines;
              painter.dispose();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: AppDurations.normal,
                    curve: AppCurves.standard,
                    alignment: Alignment.topCenter,
                    child: Text(
                      description,
                      style: style,
                      maxLines: _expanded || !overflows
                          ? null
                          : ProductOverview.collapsedLines,
                      overflow: _expanded || !overflows
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  if (overflows)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: AppButton.ghost(
                        label: _expanded ? 'Show less' : 'Read more',
                        trailingIcon: _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: AppButtonSize.sm,
                        onPressed: () =>
                            setState(() => _expanded = !_expanded),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
