import 'package:dio/dio.dart';

/// A non-2xx response, or a 2xx one whose envelope says `success: false`.
///
/// Carries the backend's own `message` (safe to show for anything but a
/// `5xx`, per the API contracts) and the optional `details` map validation
/// errors attach.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.details});

  final int? statusCode;
  final String message;
  final Map<String, dynamic>? details;

  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isUnauthorized => statusCode == 401;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when an authenticated call comes back `401` even after the one
/// automatic token refresh the Dio interceptor already tried (see
/// `api_client.dart`) — the session itself is no longer valid (revoked, or
/// the caller was never actually signed in). Shared by every user-scoped
/// repository (cart, orders) so screens can catch one type and send the user
/// back to sign in rather than retry.
class AuthRequiredException implements Exception {
  const AuthRequiredException();
}

/// Every endpoint in the catalogue and cart contracts answers with the same
/// envelope — `{success, data}` on 2xx, `{success: false, message, details}`
/// otherwise. This is the one place that unwraps it, so every repository
/// method is just "make the call, hand the parser the `data` object."
///
/// [request] is expected to throw [DioException] the normal Dio way; a
/// [DioException] carrying a response (any non-2xx) is unwrapped exactly
/// like a success is, so the same envelope parsing handles both — only a
/// request that never reached the server (no [DioException.response] at
/// all) gets the generic "no connection" message.
Future<T> apiRequest<T>(
  Future<Response<dynamic>> Function() request,
  T Function(dynamic data) parse,
) async {
  Response<dynamic> response;
  try {
    response = await request();
  } on DioException catch (e) {
    final errorResponse = e.response;
    if (errorResponse == null) {
      throw const ApiException(
        null,
        'No internet connection. Check your network and try again.',
      );
    }
    response = errorResponse;
  }

  final body = response.data;
  if (body is! Map<String, dynamic> || body['success'] != true) {
    final message = (body is Map ? body['message'] as String? : null) ??
        'Something went wrong. Please try again.';
    final details =
        body is Map ? body['details'] as Map<String, dynamic>? : null;
    throw ApiException(response.statusCode, message, details: details);
  }

  return parse(body['data']);
}
