import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// The description — collapsed to a few lines with a "Read more" toggle —
/// followed by key highlights (the first few features) as check rows.
/// Untitled: the PDP wraps it in its own section header.
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
    final highlights =
        widget.features.take(ProductOverview.maxHighlights).toList();
    final description = widget.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final style = context.text.bodySecondary.copyWith(height: 1.6);
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
                    _TextLink(
                      label: _expanded ? 'Show less' : 'Read more',
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                ],
              );
            },
          ),
        if (highlights.isNotEmpty) ...[
          if (description.isNotEmpty) const SizedBox(height: AppSpacing.mdPlus),
          for (var i = 0; i < highlights.length; i++)
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : AppSpacing.smd,
              ),
              child: _CheckRow(text: highlights[i]),
            ),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 13, color: c.primary),
        ),
        const SizedBox(width: AppSpacing.smd),
        Expanded(child: Text(text, style: context.text.body)),
      ],
    );
  }
}

/// Bare inline text action, aligned flush with the copy above it.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xsAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            label,
            style: context.text.label.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
