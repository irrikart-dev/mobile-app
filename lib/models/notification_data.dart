import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

/// One row of the notification centre (`GET /notifications`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  final String id;

  /// `ORDER_CONFIRMED`, `ORDER_SHIPPED`, … `RETURN_*`, `CAMPAIGN`.
  final String type;
  final String title;
  final String body;

  /// `orderId` / `orderNumber` for order and return updates, `link` for
  /// campaigns.
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        read: json['read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

class NotificationPage {
  const NotificationPage({required this.items, required this.unread});

  final List<AppNotification> items;
  final int unread;
}

/// The `204` endpoints here have no body, so they skip [apiRequest] (which
/// expects the envelope) and throw a plain [DioException] on failure. All of
/// them are best-effort from the app's side.
class NotificationsRepository {
  const NotificationsRepository(this._dio);

  final Dio _dio;

  Future<void> registerDevice(String fcmToken, String platform) =>
      _dio.post<dynamic>(
        '/notifications/devices',
        data: {'fcmToken': fcmToken, 'platform': platform},
      );

  Future<void> removeDevice(String fcmToken) => _dio.delete<dynamic>(
        '/notifications/devices',
        data: {'fcmToken': fcmToken},
      );

  Future<NotificationPage> list({int page = 1, int limit = 25}) async {
    try {
      return await apiRequest(
        () => _dio.get<dynamic>(
          '/notifications',
          queryParameters: {'page': page, 'limit': limit},
        ),
        (data) {
          final map = data as Map<String, dynamic>;
          return NotificationPage(
            items: ((map['items'] as List?) ?? const [])
                .map(
                  (e) => AppNotification.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
            unread: (map['unread'] as num?)?.toInt() ?? 0,
          );
        },
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) throw const AuthRequiredException();
      rethrow;
    }
  }

  Future<void> markRead(String id) =>
      _dio.post<dynamic>('/notifications/$id/read');

  Future<void> markAllRead() => _dio.post<dynamic>('/notifications/read-all');
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(dioProvider)),
);

/// The centre's list: the newest 50. ponytail: one page, add paging when
/// users actually pile up more than that.
final notificationsProvider = FutureProvider.autoDispose<NotificationPage>(
  (ref) => ref.watch(notificationsRepositoryProvider).list(limit: 50),
);

/// The bell's badge. 0 when signed out or the call fails — a badge is never
/// worth an error state.
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(isSignedInProvider)) return 0;
  try {
    final page =
        await ref.watch(notificationsRepositoryProvider).list(limit: 1);
    return page.unread;
  } catch (_) {
    return 0;
  }
});
