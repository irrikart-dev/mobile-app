import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_envelope.dart';

/// A saved card's display fields (Razorpay token `card`).
class SavedCard {
  const SavedCard({this.last4, this.network, this.issuer});

  final String? last4;

  /// `Visa`, `MasterCard`, `RuPay`…
  final String? network;

  /// Issuing bank code, e.g. `HDFC`.
  final String? issuer;

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        last4: json['last4'] as String?,
        network: json['network'] as String?,
        issuer: json['issuer'] as String?,
      );
}

/// One entry from `GET /payments/methods`. Saving happens inside the
/// Razorpay sheet (opened with the checkout's `customerId`), not through our
/// API — the app can only list and remove.
///
/// [method] is Razorpay's value (`card`, `upi`, `wallet`, `netbanking`);
/// whichever of [card], [vpa], [wallet], [bank] matches it is filled.
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.method,
    this.card,
    this.vpa,
    this.wallet,
    this.bank,
    this.createdAt,
  });

  final String id;
  final String method;
  final SavedCard? card;
  final String? vpa;
  final String? wallet;
  final String? bank;
  final DateTime? createdAt;

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    final card = json['card'];
    final created = json['createdAt'];
    return SavedPaymentMethod(
      id: json['id'] as String,
      method: json['method'] as String? ?? '',
      card: card is Map<String, dynamic> ? SavedCard.fromJson(card) : null,
      vpa: json['vpa'] as String?,
      wallet: json['wallet'] as String?,
      bank: json['bank'] as String?,
      createdAt: created is String ? DateTime.tryParse(created)?.toLocal() : null,
    );
  }

  /// "Visa •••• 4242", "ravi@okhdfc", "Paytm", "HDFC".
  String get title {
    switch (method) {
      case 'card':
        final network = _nonEmpty(card?.network) ?? 'Card';
        final last4 = _nonEmpty(card?.last4);
        return last4 == null ? network : '$network •••• $last4';
      case 'upi':
        return _nonEmpty(vpa) ?? 'UPI ID';
      case 'wallet':
        return _titleCase(_nonEmpty(wallet)) ?? 'Wallet';
      case 'netbanking':
        return _nonEmpty(bank) ?? 'Netbanking';
    }
    // Unknown method: show whichever field is filled.
    return _nonEmpty(vpa) ??
        _titleCase(_nonEmpty(wallet)) ??
        _nonEmpty(bank) ??
        (card == null ? 'Saved method' : 'Card');
  }

  /// "Credit/debit card · HDFC", "UPI", "Wallet", "Netbanking".
  String get subtitle => switch (method) {
        'card' => _nonEmpty(card?.issuer) == null
            ? 'Card'
            : 'Card · ${card!.issuer}',
        'upi' => 'UPI',
        'wallet' => 'Wallet',
        'netbanking' => 'Netbanking',
        _ => method.isEmpty ? 'Payment method' : _titleCase(method)!,
      };
}

String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s;

String? _titleCase(String? s) =>
    s == null ? null : '${s[0].toUpperCase()}${s.substring(1)}';

class SavedPaymentMethodsRepository {
  SavedPaymentMethodsRepository(this._dio);

  final Dio _dio;

  Future<List<SavedPaymentMethod>> list() async {
    try {
      return await apiRequest(
        () => _dio.get<dynamic>('/payments/methods'),
        (data) => ((data as List?) ?? const [])
            .map((e) => SavedPaymentMethod.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) throw const AuthRequiredException();
      rethrow;
    }
  }

  /// `204` on success (no body, so not run through the envelope parser);
  /// `404` if it's already gone.
  Future<void> delete(String id) async {
    try {
      await _dio.delete<dynamic>('/payments/methods/$id');
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) {
        throw const ApiException(
          null,
          'No internet connection. Check your network and try again.',
        );
      }
      if (response.statusCode == 401) throw const AuthRequiredException();
      final body = response.data;
      throw ApiException(
        response.statusCode,
        (body is Map ? body['message'] as String? : null) ??
            'Something went wrong. Please try again.',
      );
    }
  }
}

final savedPaymentMethodsRepositoryProvider =
    Provider<SavedPaymentMethodsRepository>(
  (ref) => SavedPaymentMethodsRepository(ref.watch(dioProvider)),
);

final savedPaymentMethodsProvider =
    FutureProvider.autoDispose<List<SavedPaymentMethod>>(
  (ref) => ref.watch(savedPaymentMethodsRepositoryProvider).list(),
);
