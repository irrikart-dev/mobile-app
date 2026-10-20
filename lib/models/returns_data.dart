import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

/// `REQUESTED` → `APPROVED` → `COMPLETED`, or `REJECTED` (with `adminNote`).
enum ReturnStatus { requested, approved, completed, rejected, unknown }

ReturnStatus parseReturnStatus(String? raw) => switch (raw) {
      'REQUESTED' => ReturnStatus.requested,
      'APPROVED' => ReturnStatus.approved,
      'COMPLETED' => ReturnStatus.completed,
      'REJECTED' => ReturnStatus.rejected,
      _ => ReturnStatus.unknown,
    };

String returnStatusLabel(ReturnStatus s) => switch (s) {
      ReturnStatus.requested => 'Return requested',
      ReturnStatus.approved => 'Return approved',
      ReturnStatus.completed => 'Return complete',
      ReturnStatus.rejected => 'Return declined',
      ReturnStatus.unknown => 'Return in review',
    };

/// Preset reasons for the return form; "Other" opens a text field.
const returnReasonPresets = [
  'Damaged',
  'Wrong item',
  'Not as described',
  'Missing parts',
];

class ReturnItem {
  const ReturnItem({
    required this.orderItemId,
    required this.quantity,
    required this.name,
    this.image,
  });

  final String orderItemId;
  final int quantity;
  final String name;
  final String? image;

  factory ReturnItem.fromJson(Map<String, dynamic> json) => ReturnItem(
        orderItemId: json['orderItemId'] as String,
        quantity: (json['quantity'] as num).toInt(),
        name: json['name'] as String? ?? '',
        image: json['image'] as String?,
      );
}

/// One return/replacement request, as `POST /returns`, `GET /returns` and
/// `returns[]` on `GET /orders/{id}` carry it.
class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.items,
    this.details,
    this.adminNote,
    this.resolvedAt,
  });

  final String id;

  /// `RETURN` / `REPLACE`.
  final String type;
  final ReturnStatus status;
  final String reason;
  final String? details;

  /// A message from staff to the customer — show it when present.
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final List<ReturnItem> items;

  bool get isReplacement => type == 'REPLACE';

  /// Blocks a new request on the same order.
  bool get isOpen =>
      status == ReturnStatus.requested || status == ReturnStatus.approved;

  factory ReturnRequest.fromJson(Map<String, dynamic> json) => ReturnRequest(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'RETURN',
        status: parseReturnStatus(json['status'] as String?),
        reason: json['reason'] as String? ?? '',
        details: json['details'] as String?,
        adminNote: json['adminNote'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        resolvedAt: json['resolvedAt'] is String
            ? DateTime.tryParse(json['resolvedAt'] as String)?.toLocal()
            : null,
        items: ((json['items'] as List?) ?? const [])
            .map((e) => ReturnItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ReturnsRepository {
  const ReturnsRepository(this._dio);

  final Dio _dio;

  /// `POST /returns/photos` (multipart `file`, image, max 5 MB) → its URL,
  /// the only kind `photoUrls` accepts.
  Future<String> uploadPhoto(XFile photo) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        photo.path,
        filename: photo.name,
        // The server only checks the declared type, and Dio defaults to
        // octet-stream.
        contentType: DioMediaType.parse(photo.mimeType ?? 'image/jpeg'),
      ),
    });
    return _call(
      () => _dio.post<dynamic>('/returns/photos', data: form),
      (data) => (data as Map<String, dynamic>)['url'] as String,
    );
  }

  /// [items] maps order item id → quantity; empty means "everything still
  /// returnable".
  Future<ReturnRequest> create({
    required String orderId,
    required String type,
    required String reason,
    String? details,
    List<String> photoUrls = const [],
    Map<String, int> items = const {},
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/returns',
          data: {
            'orderId': orderId,
            'type': type,
            'reason': reason.trim(),
            if (details != null && details.trim().isNotEmpty)
              'details': details.trim(),
            if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
            if (items.isNotEmpty)
              'items': [
                for (final e in items.entries)
                  {'orderItemId': e.key, 'quantity': e.value},
              ],
          },
        ),
        (data) => ReturnRequest.fromJson(data as Map<String, dynamic>),
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

final returnsRepositoryProvider = Provider<ReturnsRepository>(
  (ref) => ReturnsRepository(ref.watch(dioProvider)),
);
