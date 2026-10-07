import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../components/ui/ui.dart';
import '../../../../models/review_data.dart';

/// One review, flat: initials avatar, name + date, stars, then the comment.
/// No frame — lists separate tiles with hairline dividers.
class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    this.maxLines,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.mdPlus),
  });

  final ProductReview review;

  /// Clamp the comment (used for the PDP preview).
  final int? maxLines;

  final EdgeInsetsGeometry padding;

  static final _date = DateFormat('d MMM yyyy');

  String get _initials {
    final parts = review.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final comment = review.comment?.trim() ?? '';

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.tint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials,
                  style: context.text.label.copyWith(color: c.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.title,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _date.format(review.createdAt),
                      style: context.text.captionMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RatingStars(rating: review.rating.toDouble(), size: 15),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.smd),
            Text(
              comment,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: context.text.body.copyWith(height: 1.55),
            ),
          ],
        ],
      ),
    );
  }
}
