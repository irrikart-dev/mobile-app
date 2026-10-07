import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../reviews/view/components/review_tile.dart';
import '../../../reviews/view/reviews_providers.dart';

/// Ratings preview on the PDP: summary histogram, the two most recent
/// reviews, and a link to the full list.
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

    final header = SectionHeader(
      title: 'Ratings & reviews',
      padding: EdgeInsets.zero,
      actionLabel: 'See all',
      onAction: onSeeAll,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpacing.smd),
        async.when(
          loading: () => const _Loading(),
          error: (err, _) => AppCard(
            child: Row(
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
                  onPressed: () =>
                      ref.invalidate(productReviewsProvider(productId)),
                ),
              ],
            ),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.surfaceSunken,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_outline_rounded,
                        color: c.textMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No reviews yet', style: context.text.titleSm),
                          const SizedBox(height: 2),
                          Text(
                            'Bought this? Share how it worked for you.',
                            style: context.text.captionMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            final recent = [...reviews]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: RatingSummary(
                    average: averageRating(reviews),
                    count: reviews.length,
                    histogram: ratingHistogram(reviews),
                  ),
                ),
                for (final review in recent.take(2)) ...[
                  const SizedBox(height: AppSpacing.smd),
                  ReviewTile(review: review, maxLines: 4),
                ],
                if (reviews.length > 2) ...[
                  const SizedBox(height: AppSpacing.smd),
                  AppButton.outline(
                    label: 'See all ${reviews.length} reviews',
                    size: AppButtonSize.md,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: onSeeAll,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ShimmerBox(height: 120, borderRadius: AppRadius.mdAll),
        SizedBox(height: AppSpacing.smd),
        ShimmerBox(height: 96, borderRadius: AppRadius.mdAll),
      ],
    );
  }
}
