import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/order_data.dart';
import '../../../models/review_data.dart';
import 'write_review_sheet.dart';

/// What the PDP hands this screen — just enough to fetch reviews and, if
/// eligible, offer to write one.
class ProductReviewsArgs {
  const ProductReviewsArgs({required this.productId, required this.productName});

  final String productId;
  final String productName;
}

final _reviewsProvider = FutureProvider.family<List<ProductReview>, String>(
  (ref, productId) =>
      ref.watch(reviewsRepositoryProvider).listForProduct(productId),
);

// Same "paid, not necessarily delivered" gate as the backend — see
// reviews.service.js's REVIEWABLE_ORDER_STATUSES for why.
const _reviewableStatuses = {
  OrderStatus.confirmed,
  OrderStatus.packed,
  OrderStatus.shipped,
  OrderStatus.delivered,
};

/// The order item (if any) the signed-in caller can review this product
/// from — the most recent paid order containing it. `null` means either not
/// signed in, or no eligible purchase yet (the write-review entry point
/// hides itself in that case; a duplicate review is still caught server-side
/// as a 409, this is just about not showing the button when it's obviously
/// not applicable).
final _reviewableItemProvider = FutureProvider.family<OrderItem?, String>(
  (ref, productId) async {
    final summaries = await ref.watch(orderHistoryProvider.future);
    final eligible = summaries.where((s) => _reviewableStatuses.contains(s.status));
    final repo = ref.watch(ordersRepositoryProvider);
    for (final summary in eligible) {
      final order = await repo.getOrder(summary.id);
      for (final item in order.items) {
        if (item.productId == productId) return item;
      }
    }
    return null;
  },
);

class ProductReviewsScreen extends ConsumerWidget {
  const ProductReviewsScreen({super.key, required this.args});

  final ProductReviewsArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(_reviewsProvider(args.productId));
    final signedIn = ref.watch(isSignedInProvider);
    final reviewableAsync =
        signedIn ? ref.watch(_reviewableItemProvider(args.productId)) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Ratings & reviews')),
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text('Could not load reviews: $err')),
        data: (reviews) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_reviewsProvider(args.productId)),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (reviewableAsync?.valueOrNull != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => WriteReviewSheet(
                        productId: args.productId,
                        orderItem: reviewableAsync!.valueOrNull!,
                        onSubmitted: () =>
                            ref.invalidate(_reviewsProvider(args.productId)),
                      ),
                    ),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Write a review'),
                  ),
                ),
              if (reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No reviews yet for ${args.productName}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final review in reviews) _ReviewTile(review: review),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExt>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review.userName, style: theme.textTheme.titleSmall),
              const Spacer(),
              for (var i = 0; i < 5; i++)
                Icon(
                  i < review.rating ? Icons.star_rounded : Icons.star_outline,
                  size: 16,
                  color: ext.warning,
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 6),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
