import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'api_config.dart';

/// Marks a request as exempt from this interceptor's own 401 remedies (token
/// refresh + account sync) — used on the sync call itself, so a genuinely bad
/// token can't send it recursing into itself.
const _skipAuthRetryKey = 'skipAuthRetry';

/// The single Dio instance for the app.
///
/// The catalogue is public, so most requests leave with no auth header at
/// all. User-scoped endpoints (cart, orders) need a Firebase ID token; rather
/// than have every repository fetch and attach one, this interceptor does it
/// once for every request that has a signed-in user.
///
/// A `401` gets exactly one retry, against two independent remedies tried
/// together (each a no-op if it wasn't the actual problem):
///  - a force-refreshed token — the contracts specify `checkRevoked: true`,
///    so a server-side "log out all devices" invalidates a cached token
///    mid-session;
///  - `POST /auth/firebase/sync` — the backend keeps its own `User` row
///    per Firebase account and 401s with "No account linked to this
///    Firebase user" until that row exists. Nothing in the catalogue, cart
///    or checkout contracts told the app to call this, so a signed-in
///    Firebase user could reach the cart with a perfectly valid token and
///    still get rejected. Calling this here means the app never needs a
///    dedicated "did we sync yet" flag — a 401 for this reason simply heals
///    itself on the next request instead of surfacing as "please sign in
///    again" for a user who very much is.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _currentIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final skip = error.requestOptions.extra[_skipAuthRetryKey] == true;
        final alreadyRetried =
            error.requestOptions.extra['authRetried'] == true;
        if (skip || error.response?.statusCode != 401 || alreadyRetried) {
          return handler.next(error);
        }

        await _ensureSynced(dio);
        final freshToken = await _currentIdToken(forceRefresh: true);
        if (freshToken == null) return handler.next(error);

        try {
          final retryOptions = error.requestOptions
            ..headers['Authorization'] = 'Bearer $freshToken'
            ..extra['authRetried'] = true;
          final response = await dio.fetch<dynamic>(retryOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        // Headers + response body on in debug — this is what shows whether
        // the Authorization header actually went out and what the backend
        // said back, which matters far more than it costs during dev.
        requestHeader: true,
        requestBody: false,
        responseBody: true,
        compact: true,
      ),
    );
  }

  ref.onDispose(dio.close);
  return dio;
});

/// Null when Firebase isn't configured, or no one is signed in — both mean
/// "send the request unauthenticated," which is correct for the public
/// catalogue and produces the expected `401` for the cart.
Future<String?> _currentIdToken({bool forceRefresh = false}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken(forceRefresh);
  } catch (_) {
    return null;
  }
}

/// Deduplicates concurrent callers — if the cart and orders screens both hit
/// a 401 for the same missing-account reason at once, this makes sure only
/// one `sync` call actually goes out.
Future<void>? _syncInFlight;

/// Best-effort — a real problem (bad token, network down) surfaces from the
/// retry that follows this, not from here.
Future<void> _ensureSynced(Dio dio) {
  return _syncInFlight ??= dio
      .post<dynamic>(
        '/auth/firebase/sync',
        options: Options(extra: {_skipAuthRetryKey: true}),
      )
      .then((_) {})
      .catchError((_) {})
      .whenComplete(() => _syncInFlight = null);
}
