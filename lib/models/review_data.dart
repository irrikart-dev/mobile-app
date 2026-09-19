import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

/// One published review, from `GET /reviews/product/{productId}`. Auto-
/// approved server-side — there is no moderation queue yet, so every
/// submitted review shows up here.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.userName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? comment;
  final String userName;
  final DateTime createdAt;

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: json['id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      userName: json['userName'] as String? ?? 'Verified buyer',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class ReviewsRepository {
  ReviewsRepository(this._dio);

  final Dio _dio;

  Future<List<ProductReview>> listForProduct(String productId) => apiRequest(
        () => _dio.get<dynamic>('/reviews/product/$productId'),
        (data) => (data as List)
            .map((e) => ProductReview.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Gated server-side to a paid order item the caller owns, one review per
  /// item — a 400/409 here means "not paid yet" / "already reviewed",
  /// respectively. See `docs/app-checkout-payment-api-contract.md` §reviews
  /// once that section exists; for now the two failure cases are exactly
  /// those two status codes.
  Future<void> submit({
    required String orderItemId,
    required int rating,
    String? comment,
  }) =>
      apiRequest(
        () => _dio.post<dynamic>(
          '/reviews',
          data: {
            'orderItemId': orderItemId,
            'rating': rating,
            if (comment != null && comment.trim().isNotEmpty)
              'comment': comment.trim(),
          },
        ),
        (data) => null,
      );
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(ref.watch(dioProvider)),
);
