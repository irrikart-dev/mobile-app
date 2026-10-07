import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// Read-only five-star row with half-star support.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: rating >= i - 0.5 ? c.rating : c.borderStrong,
          ),
      ],
    );
  }
}

/// Compact "★ 4.6 (128)" label used on cards and the PDP title row.
class RatingLabel extends StatelessWidget {
  const RatingLabel({
    super.key,
    required this.rating,
    required this.count,
    this.compact = true,
  });

  final double rating;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (count == 0) {
      return Text('No reviews yet', style: context.text.captionMuted);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: compact ? 14 : 16, color: c.rating),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: context.text.caption.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          compact ? '($count)' : '· $count review${count == 1 ? '' : 's'}',
          style: context.text.captionMuted,
        ),
      ],
    );
  }
}

/// Average + star histogram header for reviews.
class RatingSummary extends StatelessWidget {
  const RatingSummary({
    super.key,
    required this.average,
    required this.count,
    required this.histogram,
  });

  final double average;
  final int count;

  /// Star (1–5) → number of reviews.
  final Map<int, int> histogram;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxCount = histogram.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: context.text.display.copyWith(fontSize: 40),
              ),
              RatingStars(rating: average, size: 15),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$count review${count == 1 ? '' : 's'}',
                style: context.text.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            children: [
              for (var star = 5; star >= 1; star--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        child: Text('$star', style: context.text.caption),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: AppRadius.pillAll,
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: maxCount == 0
                                ? 0
                                : (histogram[star] ?? 0) / maxCount,
                            color: c.rating,
                            backgroundColor: c.surfaceSunken,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${histogram[star] ?? 0}',
                          textAlign: TextAlign.end,
                          style: context.text.captionMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tappable star input for the write-review sheet.
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedScale(
                scale: value == i ? 1.12 : 1,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  value >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: value >= i ? c.rating : c.borderStrong,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
