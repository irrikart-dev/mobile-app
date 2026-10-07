import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../reviews/view/components/review_tile.dart';
import '../../../reviews/view/reviews_providers.dart';

/// Ratings preview on the PDP, flat: summary histogram, the two most recent
/// reviews separated by hairlines, and a link to the full list. The PDP
/// supplies the section title.
class PdpReviewsSection extends ConsumerWidget {
  const PdpReviewsSection({
    super.key,
    required this.productId,
    required this.fallbackRating,
    required this.fallbackCount,
    required this.onSeeAll,
  });

  final String productId;

  /// Catalogue aggregate, shown if the reviews call fails or is loading.
  final double fallbackRating;
  final int fallbackCount;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(productReviewsProvider(productId));

    return async.when(
      loading: () => const _Loading(),
      error: (err, _) => Row(
        children: [
          Expanded(
            child: fallbackCount > 0
                ? RatingLabel(
                    rating: fallbackRating,
                    count: fallbackCount,
                    compact: false,
                  )
                : Text(
                    'Couldn’t load reviews',
                    style: context.text.bodySecondary,
                  ),
          ),
          AppButton.ghost(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            size: AppButtonSize.sm,
            onPressed: () => ref.invalidate(productReviewsProvider(productId)),
          ),
        ],
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(color: c.tint, shape: BoxShape.circle),
                child: Icon(
                  Icons.star_rounded,
                  color: c.primary,
                  size: AppIconSize.md - 2,
                ),
              ),
              const SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No reviews yet', style: context.text.title),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Bought this? Share how it worked for you.',
                      style: context.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        final recent = [...reviews]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RatingSummary(
              average: averageRating(reviews),
              count: reviews.length,
              histogram: ratingHistogram(reviews),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final review in recent.take(2)) ...[
              Divider(height: 1, color: c.divider),
              ReviewTile(review: review, maxLines: 4),
            ],
            if (reviews.length > 2) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton.secondary(
                label: 'Read all ${reviews.length} reviews',
                size: AppButtonSize.md,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: onSeeAll,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(height: 96, borderRadius: AppRadius.mdAll),
        SizedBox(height: AppSpacing.mdPlus),
        ShimmerBox(height: 14, width: 160),
        SizedBox(height: AppSpacing.sm),
        ShimmerBox(height: 12),
        SizedBox(height: AppSpacing.xs + 2),
        ShimmerBox(height: 12, width: 220),
      ],
    );
  }
}
