import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Thrown by [SignupApi] with a message that is already safe to show a user.
class SignupApiException implements Exception {
  const SignupApiException(this.userMessage);

  final String userMessage;

  @override
  String toString() => 'SignupApiException: $userMessage';
}

/// Talks to the backend's OTP email sign-up flow: request a code, verify it,
/// then set a password to finish.
///
/// The account itself is created server-side (Firebase Admin SDK) only once
/// the code is verified — that is what lets the backend guarantee the email
/// was actually reachable before anything exists for it. The last step hands
/// back a Firebase custom token; [AuthService.signInWithCustomToken] uses it
/// to sign this device into the account that was just created.
class SignupApi {
  SignupApi(this._dio);

  final Dio _dio;

  /// Step 1. Emails a 6-digit code to [email].
  Future<void> requestOtp(String email) =>
      _post('/auth/signup/request-otp', {'email': email});

  /// Step 2. Verifies [otp], returning a short-lived signup token that
  /// proves the email was checked.
  Future<String> verifyOtp(String email, String otp) async {
    final data = await _post('/auth/signup/verify-otp', {
      'email': email,
      'otp': otp,
    });
    return data['signupToken'] as String;
  }

  /// Step 3. Creates the account with [password] and returns a Firebase
  /// custom token to sign in with.
  Future<String> completeSignup(String signupToken, String password) async {
    final data = await _post('/auth/signup/complete', {
      'signupToken': signupToken,
      'password': password,
    });
    return data['customToken'] as String;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      return (res.data?['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (e) {
      throw SignupApiException(_messageFor(e));
    }
  }

  static String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      // The backend's validation errors come back as {field: message}; any
      // one of them is fine to show — the form only ever submits one field
      // worth asking about at a time.
      final fields = data['fields'];
      if (fields is Map && fields.isNotEmpty) {
        return fields.values.first.toString();
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final signupApiProvider = Provider<SignupApi>(
  (ref) => SignupApi(ref.watch(dioProvider)),
);
