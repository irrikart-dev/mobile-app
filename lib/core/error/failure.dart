import 'error_codes.dart';

/// The single error type that crosses the repository boundary.
///
/// Repositories **throw** these; presentation catches them via
/// `AsyncValue.guard`. There is deliberately no `Either`/`Result` wrapper —
/// Riverpod's [AsyncValue] already carries error and stack trace, and layering
/// a second monad on top means unwrapping twice and losing stack traces.
///
/// [userMessage] is the only string that should ever be shown to a user.
/// [message] is for logs and Sentry.
sealed class Failure implements Exception {
  const Failure({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  /// Developer-facing detail. Never rendered in the UI.
  final String message;

  /// Server error code from [ErrorCodes], when the server supplied one.
  final String? code;

  final Object? cause;
  final StackTrace? stackTrace;

  /// Safe to render. Subclasses override with something a farmer would
  /// understand — no status codes, no exception class names.
  String get userMessage;

  /// Whether offering a "Retry" button makes sense.
  bool get isRetryable => false;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// No usable connection, DNS failure, or the request never left the device.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No network connection',
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage =>
      'You appear to be offline. Check your connection and try again.';

  @override
  bool get isRetryable => true;
}

/// Connect, send or receive timeout.
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'Request timed out',
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'That took too long. Please try again.';

  @override
  bool get isRetryable => true;
}

/// 5xx, or a response the client could not make sense of.
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    this.statusCode,
    super.code,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;

  @override
  String get userMessage =>
      'Something went wrong at our end. Please try again in a moment.';

  @override
  bool get isRetryable => true;
}

/// 401/403 — not signed in, session dead, or not permitted.
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });

  /// True when the session is unrecoverable and the user must sign in again.
  bool get requiresReauth =>
      code == ErrorCodes.tokenExpired || code == ErrorCodes.tokenRevoked;

  @override
  String get userMessage => switch (code) {
        ErrorCodes.invalidCredentials =>
          'That email or password is not correct.',
        ErrorCodes.otpInvalid => 'That OTP is not correct.',
        ErrorCodes.otpExpired => 'That OTP has expired. Request a new one.',
        ErrorCodes.otpAttemptsExceeded =>
          'Too many incorrect attempts. Request a new OTP.',
        ErrorCodes.otpResendTooSoon =>
          'Please wait a few seconds before requesting another OTP.',
        ErrorCodes.accountBlocked =>
          'This account has been blocked. Contact support for help.',
        ErrorCodes.phoneAlreadyRegistered =>
          'This mobile number is already registered. Try signing in.',
        _ => 'Your session has ended. Please sign in again.',
      };
}

/// 422 — per-field validation errors from the server.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    this.fieldErrors = const {},
    super.code = ErrorCodes.validationError,
    super.cause,
    super.stackTrace,
  });

  /// Field name to the first error for that field.
  final Map<String, String> fieldErrors;

  @override
  String get userMessage => fieldErrors.values.firstOrNull ?? message;
}

/// 404.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.code = ErrorCodes.notFound,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'We could not find what you were looking for.';
}

/// 429, or a local rate limit.
class RateLimitFailure extends Failure {
  const RateLimitFailure({
    required super.message,
    this.retryAfter,
    super.code = ErrorCodes.rateLimited,
    super.cause,
    super.stackTrace,
  });

  /// From the `Retry-After` header, when present.
  final Duration? retryAfter;

  @override
  String get userMessage => 'Too many requests. Please try again shortly.';

  @override
  bool get isRetryable => true;
}

/// A rule the business defines, surfaced to the user as-is.
///
/// Out of stock, coupon expired, pincode not serviceable. The server's
/// message is intentionally shown, because it is the most specific
/// explanation available.
class BusinessFailure extends Failure {
  const BusinessFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => message;
}

/// Local storage read/write failed.
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Could not read saved data on this device.';
}

/// Anything not otherwise classified. Always worth reporting to Sentry.
class UnknownFailure extends Failure {
  const UnknownFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Something went wrong. Please try again.';

  @override
  bool get isRetryable => true;
}
