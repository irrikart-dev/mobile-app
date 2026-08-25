import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'error_codes.dart';
import 'failure.dart';

/// Converts anything thrown below the repository layer into a [Failure].
///
/// This is the only place in the app that knows about [DioException].
/// Repositories wrap their data-source calls in
/// `try { ... } catch (e, st) { throw ErrorMapper.toFailure(e, st); }`.
abstract final class ErrorMapper {
  static Failure toFailure(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is DioException) return _fromDio(error, stackTrace);

    if (error is SocketException) {
      return NetworkFailure(
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return TimeoutFailure(
        message: error.message ?? 'Timed out',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return ServerFailure(
        message: 'Malformed response: ${error.message}',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UnknownFailure(
      message: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static Failure _fromDio(DioException e, StackTrace? stackTrace) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(message: e.message ?? 'Timed out', cause: e);

      case DioExceptionType.connectionError:
        return NetworkFailure(
            message: e.message ?? 'Connection failed', cause: e);

      case DioExceptionType.cancel:
        return UnknownFailure(message: 'Request cancelled', cause: e);

      case DioExceptionType.badCertificate:
        return NetworkFailure(message: 'Bad TLS certificate', cause: e);

      case DioExceptionType.badResponse:
        return _fromResponse(e, stackTrace);

      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return NetworkFailure(message: 'No connection', cause: e);
        }
        return UnknownFailure(message: e.message ?? 'Request failed', cause: e);
    }
  }

  static Failure _fromResponse(DioException e, StackTrace? stackTrace) {
    final response = e.response;
    final status = response?.statusCode ?? 0;
    final body = response?.data;

    // Envelope shape: { "success": false, "error": { "code", "message", "fields" } }
    String? code;
    String? serverMessage;
    Map<String, String> fieldErrors = const {};

    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        code = err['code'] as String?;
        serverMessage = err['message'] as String?;
        final fields = err['fields'];
        if (fields is Map) {
          fieldErrors = fields.map(
            (k, v) => MapEntry(k.toString(), _firstString(v)),
          );
        }
      } else {
        serverMessage = body['message'] as String?;
      }
    }

    final message = serverMessage ?? e.message ?? 'HTTP $status';

    return switch (status) {
      401 || 403 => AuthFailure(
          message: message,
          code: code ?? ErrorCodes.tokenExpired,
          cause: e,
          stackTrace: stackTrace,
        ),
      404 => NotFoundFailure(message: message, code: code, cause: e),
      409 || 422 => fieldErrors.isNotEmpty
          ? ValidationFailure(
              message: message,
              fieldErrors: fieldErrors,
              code: code ?? ErrorCodes.validationError,
              cause: e,
            )
          : BusinessFailure(message: message, code: code, cause: e),
      429 => RateLimitFailure(
          message: message,
          retryAfter: _retryAfter(response),
          code: code,
          cause: e,
        ),
      >= 400 && < 500 => BusinessFailure(
          message: message,
          code: code,
          cause: e,
          stackTrace: stackTrace,
        ),
      _ => ServerFailure(
          message: message,
          statusCode: status,
          code: code,
          cause: e,
          stackTrace: stackTrace,
        ),
    };
  }

  static String _firstString(Object? value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value.toString();
  }

  static Duration? _retryAfter(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
