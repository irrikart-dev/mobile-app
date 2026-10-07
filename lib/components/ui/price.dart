import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/formatters.dart';

/// A rupee amount in the price style.
class PriceText extends StatelessWidget {
  const PriceText(this.amount, {super.key, this.large = false, this.color});

  final num amount;
  final bool large;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = large ? context.text.priceLarge : context.text.price;
    return Text(
      formatInr(amount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: color == null ? style : style.copyWith(color: color),
    );
  }
}

/// Price, optional MRP strike-through with "% off", and the pack unit.
///
/// The catalogue has no MRP today, so [mrp] is usually null — the block then
/// reads "₹1,299 / piece". When promotions land the strike and discount show
/// up everywhere without touching a screen.
class PriceBlock extends StatelessWidget {
  const PriceBlock({
    super.key,
    required this.price,
    this.mrp,
    this.unit,
    this.large = false,
    this.note,
  });

  final num price;
  final num? mrp;
  final String? unit;
  final bool large;

  /// Small line under the price, e.g. "Inclusive of all taxes".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDiscount = mrp != null && mrp! > price;
    final pct = hasDiscount ? (((mrp! - price) / mrp!) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            PriceText(price, large: large),
            if (unit != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(formatUnit(unit!), style: context.text.caption),
              ),
            if (hasDiscount) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(formatInr(mrp!), style: context.text.priceStrike),
              ),
              DiscountTag(percent: pct),
            ],
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(note!, style: context.text.caption.copyWith(color: c.textMuted)),
        ],
      ],
    );
  }
}

class DiscountTag extends StatelessWidget {
  const DiscountTag({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.successSoft,
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        '$percent% off',
        style: context.text.badge.copyWith(color: c.discount),
      ),
    );
  }
}

/// "Label ....... value" row used in price breakdowns and order summaries.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        emphasize ? context.text.title : context.text.bodySecondary;
    final valueStyle = emphasize ? context.text.h3 : context.text.bodyStrong;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(
            value,
            style: valueColor == null
                ? valueStyle
                : valueStyle.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
