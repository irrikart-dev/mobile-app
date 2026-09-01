import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'api_config.dart';

/// The single Dio instance for the app.
///
/// Kept deliberately thin: the catalogue is public, so there is no auth
/// interceptor here yet. When authenticated endpoints (orders, wishlist)
/// arrive, attach the Firebase ID token in one interceptor added below.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseBody: false,
        compact: true,
      ),
    );
  }

  ref.onDispose(dio.close);
  return dio;
});
