import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

/// A bulk quote request (`/rfq`). A lead for IrriKart staff, who reply by
/// phone or email outside the app — never a price or an order.
class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.status,
    required this.quantity,
    required this.createdAt,
    this.requirements,
    this.targetPrice,
    this.productTitle,
    this.productSlug,
  });

  final String id;

  /// `NEW` / `CONTACTED` / `CLOSED`.
  final String status;
  final int quantity;
  final String? requirements;
  final num? targetPrice;

  /// Null for a requirements-only request.
  final String? productTitle;
  final String? productSlug;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'CONTACTED' => 'We’ve contacted you',
        'CLOSED' => 'Closed',
        _ => 'Submitted',
      };

  factory QuoteRequest.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return QuoteRequest(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'NEW',
      quantity: (json['quantity'] as num).toInt(),
      requirements: json['requirements'] as String?,
      targetPrice: json['targetPrice'] as num?,
      productTitle: product?['title'] as String?,
      productSlug: product?['slug'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class RfqRepository {
  const RfqRepository(this._dio);

  final Dio _dio;

  /// Send [productId], non-empty [requirements], or both.
  Future<QuoteRequest> submit({
    String? productId,
    required int quantity,
    String? requirements,
    num? targetPrice,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/rfq',
          data: {
            if (productId != null) 'productId': productId,
            'quantity': quantity,
            if (requirements != null && requirements.trim().isNotEmpty)
              'requirements': requirements.trim(),
            if (targetPrice != null) 'targetPrice': targetPrice,
          },
        ),
        (data) => QuoteRequest.fromJson(data as Map<String, dynamic>),
      );

  Future<List<QuoteRequest>> listMine() => _call(
        () => _dio.get<dynamic>('/rfq'),
        (data) => (data as List)
            .map((e) => QuoteRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      return await apiRequest(request, parse);
    } on ApiException catch (e) {
      if (e.isUnauthorized) throw const AuthRequiredException();
      rethrow;
    }
  }
}

final rfqRepositoryProvider = Provider<RfqRepository>(
  (ref) => RfqRepository(ref.watch(dioProvider)),
);

final myQuoteRequestsProvider = FutureProvider.autoDispose<List<QuoteRequest>>(
  (ref) => ref.watch(rfqRepositoryProvider).listMine(),
);
