import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Where the IrriKart API lives.
///
/// Override at build time, which is how CI points a build at staging or prod:
///
///   flutter run --dart-define=IRRIKART_API_BASE_URL=https://api.irrikart.in/api/v1
///
/// With no override, debug builds fall back to a local backend. The Android
/// emulator reaches the host machine on 10.0.2.2, not localhost.
abstract final class ApiConfig {
  static const String _override =
      String.fromEnvironment('IRRIKART_API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return 'https://api.irrikart.in/api/v1';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000/api/v1';
    return 'http://localhost:4000/api/v1';
  }

  /// The API serves catalogue images from `/static/...` on this origin.
  static String get assetOrigin => baseUrl.endsWith('/api/v1')
      ? baseUrl.substring(0, baseUrl.length - '/api/v1'.length)
      : baseUrl;

  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 12);
}
