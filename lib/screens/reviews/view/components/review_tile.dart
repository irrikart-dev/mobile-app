import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../components/ui/ui.dart';
import '../../../../models/review_data.dart';

/// One review: initials avatar, name + date, stars and the comment.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.maxLines});

  final ProductReview review;

  /// Clamp the comment (used for the PDP preview).
  final int? maxLines;

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

    return AppCard(
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
                  color: c.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials,
                  style: context.text.label.copyWith(color: c.onPrimarySoft),
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
                      style: context.text.titleSm,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _date.format(review.createdAt),
                      style: context.text.captionMuted,
                    ),
                  ],
                ),
              ),
              RatingStars(rating: review.rating.toDouble(), size: 15),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.smd),
            Text(
              comment,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: context.text.body,
            ),
          ],
        ],
      ),
    );
  }
}
