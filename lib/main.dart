import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/components/whatsapp_support_fab.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/startup/app_bootstrap.dart';
import 'package:irrikart/core/storage/local_store.dart';
import 'package:irrikart/core/theme/app_theme.dart';
import 'package:irrikart/core/theme/theme_mode_controller.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/route/route_tracker.dart';
import 'package:irrikart/route/router.dart' as router;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Decided before the first frame, while the native splash is still up —
  // so there's never a flash of onboarding/sign-in on the way to home.
  final startup = await bootstrapApp();

  runApp(
    ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWithValue(startup.firebaseStatus),
        sharedPreferencesProvider.overrideWithValue(startup.prefs),
      ],
      child: IrriKartApp(initialRoute: startup.initialRoute),
    ),
  );
}

class IrriKartApp extends ConsumerStatefulWidget {
  const IrriKartApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  ConsumerState<IrriKartApp> createState() => _IrriKartAppState();
}

/// The catalogue contract's freshness rule 2: "re-fetch the visible screen
/// when the app returns from background after more than 60 s."
const _foregroundRevalidateAfter = Duration(seconds: 60);

class _IrriKartAppState extends ConsumerState<IrriKartApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  final _routeTracker = RouteTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AsyncValue<User?>>(authStateProvider, _onAuthChanged);
  }

  /// A session that ends without the user tapping Log out (revoked, disabled,
  /// expired refresh token) would otherwise leave them on screens that now
  /// 401 on every call. Send them to sign-in with an explanation instead.
  void _onAuthChanged(AsyncValue<User?>? previous, AsyncValue<User?> next) {
    final wasSignedIn = previous?.valueOrNull != null;
    final isSignedIn = next.valueOrNull != null;
    if (!wasSignedIn || isSignedIn) return;

    if (AuthService.explicitSignOutPending) {
      AuthService.explicitSignOutPending = false;
      return;
    }
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(logInScreenRoute, (_) => false);
    ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
      const SnackBar(content: Text('Your session ended. Please sign in again.')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;

    if (DateTime.now().difference(backgroundedAt) > _foregroundRevalidateAfter) {
      ref.invalidate(catalogDataProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IrriKart',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [_routeTracker],
      onGenerateRoute: router.generateRoute,
      initialRoute: widget.initialRoute,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const WhatsAppSupportFab(),
        ],
      ),
    );
  }
}
