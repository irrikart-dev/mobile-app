import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_envelope.dart';
import 'auth_validators.dart';

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(ref.watch(dioProvider)),
);

/// The backend's copy of the signed-in user's profile (`/auth/me`). Firebase
/// keeps its own display name; orders and invoices read this one, so every
/// name change has to land in both.
class ProfileApi {
  const ProfileApi(this._dio);

  final Dio _dio;

  /// `PATCH /auth/me {name}` — [name] is trimmed; must be 1–100 characters.
  /// Throws [ApiException] on failure.
  Future<void> updateName(String name) {
    final trimmed = name.trim();
    assert(
      AuthValidators.nameError(trimmed) == null,
      'validate the name before sending it',
    );
    return apiRequest(
      () => _dio.patch<dynamic>('/auth/me', data: {'name': trimmed}),
      (_) {},
    );
  }
}
