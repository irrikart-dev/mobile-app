import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/components/whatsapp_support_fab.dart';
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

  final hasSession =
      firebaseStatus == FirebaseStatus.ready && await _hasRestoredSession();

  runApp(
    ProviderScope(
      overrides: [firebaseStatusProvider.overrideWithValue(firebaseStatus)],
      child: IrriKartApp(
        initialRoute: hasSession ? entryPointScreenRoute : onbordingScreenRoute,
      ),
    ),
  );
}

/// Whether a signed-in session survives this cold start.
///
/// `currentUser` is a cached getter — on some devices/SDK timings it can
/// still read null immediately after `initializeApp()` resolves, before the
/// native side has finished restoring the persisted user (the previous fix
/// here assumed `authStateChanges()` always beats that race — it apparently
/// doesn't reliably on every device, since this still logged people out).
/// So: check the fast synchronous path first, and only fall back to
/// awaiting the stream (bounded by a timeout, so a stream that never fires
/// can't hang the splash forever) if that path says null.
Future<bool> _hasRestoredSession() async {
  if (FirebaseAuth.instance.currentUser != null) return true;
  try {
    final user = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5));
    return user != null;
  } catch (_) {
    return FirebaseAuth.instance.currentUser != null;
  }
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
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const WhatsAppSupportFab(),
        ],
      ),
    );
  }
}
