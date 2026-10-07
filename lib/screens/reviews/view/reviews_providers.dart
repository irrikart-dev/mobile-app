import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/order_data.dart';
import '../../../models/review_data.dart';

/// Published reviews for one product. Shared by the PDP's reviews preview
/// and the full reviews screen so both read the same cache.
final productReviewsProvider =
    FutureProvider.autoDispose.family<List<ProductReview>, String>(
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
final reviewableItemProvider = FutureProvider.family<OrderItem?, String>(
  (ref, productId) async {
    final summaries = await ref.watch(orderHistoryProvider.future);
    final eligible =
        summaries.where((s) => _reviewableStatuses.contains(s.status));
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

/// Star (1–5) → count, for [RatingSummary].
Map<int, int> ratingHistogram(List<ProductReview> reviews) {
  final map = {for (var s = 1; s <= 5; s++) s: 0};
  for (final r in reviews) {
    final star = r.rating.clamp(1, 5);
    map[star] = map[star]! + 1;
  }
  return map;
}

double averageRating(List<ProductReview> reviews) {
  if (reviews.isEmpty) return 0;
  return reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
}
