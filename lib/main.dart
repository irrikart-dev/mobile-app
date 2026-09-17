import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/firebase/firebase_bootstrap.dart';
import 'package:irrikart/core/theme/app_theme.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/route/router.dart' as router;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved once, then read everywhere through `firebaseStatusProvider`.
  // A failure here does not stop the app: the catalogue stays browsable and
  // only the sign-in screens degrade. See `bootstrapFirebase`.
  final firebaseStatus = await bootstrapFirebase();

  // Firebase persists the signed-in user across app launches on its own —
  // by the time `Firebase.initializeApp()` above has resolved, the native
  // SDK has already loaded any saved credential, so `currentUser` here is
  // reliable. Previously this was ignored and every cold start hardcoded
  // the onboarding route, which forced a real returning user back through
  // onboarding -> login every single time — indistinguishable from actually
  // being logged out. Route straight past both when a session already exists.
  final hasSession = firebaseStatus == FirebaseStatus.ready &&
      FirebaseAuth.instance.currentUser != null;

  runApp(
    ProviderScope(
      overrides: [firebaseStatusProvider.overrideWithValue(firebaseStatus)],
      child: IrriKartApp(
        initialRoute: hasSession ? entryPointScreenRoute : onbordingScreenRoute,
      ),
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
/// when the app returns from background after more than 60 s." There is no
/// per-screen visibility tracking here — simplest correct implementation is
/// invalidating the one shared [catalogDataProvider], which every catalogue
/// screen already rebuilds from.
const _foregroundRevalidateAfter = Duration(seconds: 60);

class _IrriKartAppState extends ConsumerState<IrriKartApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    if (DateTime.now().difference(backgroundedAt) >
        _foregroundRevalidateAfter) {
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
      themeMode: ThemeMode.system,
      onGenerateRoute: router.generateRoute,
      initialRoute: widget.initialRoute,
    );
  }
}
