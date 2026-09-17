/// Where the IrriKart API lives.
///
/// Debug and release both default to the hosted Vercel backend now — that's
/// what's actually running. Override at build/run time to point at a local
/// backend instead (the Android emulator reaches the host machine on
/// 10.0.2.2, not localhost):
///
///   flutter run --dart-define=IRRIKART_API_BASE_URL=http://10.0.2.2:4000/api/v1
///
/// or CI pointing a build at a different environment:
///
///   flutter run --dart-define=IRRIKART_API_BASE_URL=https://backend-pied-zeta-12.vercel.app/api/v1
abstract final class ApiConfig {
  static const String _override =
      String.fromEnvironment('IRRIKART_API_BASE_URL');

  static const String _hostedBaseUrl =
      'https://backend-pied-zeta-12.vercel.app/api/v1';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return _hostedBaseUrl;
  }

  /// The API serves catalogue images from `/static/...` on this origin.
  static String get assetOrigin => baseUrl.endsWith('/api/v1')
      ? baseUrl.substring(0, baseUrl.length - '/api/v1'.length)
      : baseUrl;

  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 12);
}
