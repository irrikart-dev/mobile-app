import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../models/review_data.dart';
import 'components/review_tile.dart';
import 'reviews_providers.dart';
import 'write_review_sheet.dart';

/// What the PDP hands this screen — just enough to fetch reviews and, if
/// eligible, offer to write one.
class ProductReviewsArgs {
  const ProductReviewsArgs({
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;
}

class ProductReviewsScreen extends ConsumerWidget {
  const ProductReviewsScreen({super.key, required this.args});

  final ProductReviewsArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(productReviewsProvider(args.productId));
    final signedIn = ref.watch(isSignedInProvider);
    final reviewable = signedIn
        ? ref.watch(reviewableItemProvider(args.productId)).valueOrNull
        : null;

    void openWriteSheet() => showWriteReviewSheet(
          context,
          productId: args.productId,
          orderItem: reviewable!,
          onSubmitted: () =>
              ref.invalidate(productReviewsProvider(args.productId)),
        );

    Future<void> refresh() async {
      ref.invalidate(productReviewsProvider(args.productId));
      await ref.read(productReviewsProvider(args.productId).future);
    }

    return Scaffold(
      appBar: AppTopBar(title: 'Reviews', subtitle: args.productName),
      body: reviewsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const _ReviewsSkeleton(),
        error: (err, _) => ErrorState(
          error: err,
          onRetry: () => ref.invalidate(productReviewsProvider(args.productId)),
        ),
        data: (reviews) => RefreshIndicator(
          onRefresh: refresh,
          child: reviews.isEmpty
              ? _EmptyReviews(
                  productName: args.productName,
                  onWrite: reviewable == null ? null : openWriteSheet,
                )
              : _ReviewsList(
                  reviews: reviews,
                  onWrite: reviewable == null ? null : openWriteSheet,
                ),
        ),
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.reviews, required this.onWrite});

  final List<ProductReview> reviews;
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sorted = [...reviews]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _pad,
        AppSpacing.md,
        _pad,
        AppSpacing.xl + context.bottomInset,
      ),
      children: [
        RatingSummary(
          average: averageRating(reviews),
          count: reviews.length,
          histogram: ratingHistogram(reviews),
        ),
        if (onWrite != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _WritePrompt(onWrite: onWrite!),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          '${reviews.length} REVIEW${reviews.length == 1 ? '' : 'S'}'
          ' · NEWEST FIRST',
          style: context.text.overline,
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) Divider(height: 1, color: c.divider),
          ReviewTile(review: sorted[i]),
        ],
      ],
    );
  }
}

/// Page padding for the reviews list.
const double _pad = AppSpacing.mdPlus;

class _WritePrompt extends StatelessWidget {
  const _WritePrompt({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.tint,
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 2,
          AppSpacing.md,
          AppSpacing.smd,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You bought this', style: context.text.title),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Help other farmers decide',
                    style: context.text.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Write a review',
              icon: Icons.rate_review_rounded,
              size: AppButtonSize.sm,
              expand: false,
              onPressed: onWrite,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({required this.productName, required this.onWrite});

  final String productName;
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works on an empty list.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyState(
            icon: Icons.reviews_rounded,
            title: 'No reviews yet',
            message: onWrite == null
                ? 'Be the first to share how $productName works for you once '
                    'you have bought it.'
                : 'You bought $productName — be the first to review it.',
            actionLabel: onWrite == null ? null : 'Write a review',
            onAction: onWrite,
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: ShimmerBox(height: 6),
      );
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const review = Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.mdPlus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(
                height: 40,
                width: 40,
                borderRadius: AppRadius.pillAll,
              ),
              SizedBox(width: AppSpacing.smd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 12, width: 120),
                  SizedBox(height: 6),
                  ShimmerBox(height: 10, width: 72),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.smd),
          ShimmerBox(height: 12),
          SizedBox(height: 6),
          ShimmerBox(height: 12, width: 200),
        ],
      ),
    );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(_pad, AppSpacing.md, _pad, 0),
      children: [
        const Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 40, width: 64),
                SizedBox(height: AppSpacing.sm),
                ShimmerBox(height: 12, width: 84),
              ],
            ),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                children: [_Bar(), _Bar(), _Bar(), _Bar(), _Bar()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) Divider(height: 1, color: c.divider),
          review,
        ],
      ],
    );
  }
}
