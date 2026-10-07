import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../route/route_constants.dart';
import '../firebase/firebase_bootstrap.dart';
import '../storage/local_store.dart';

/// Everything the app needs decided before its first frame. Runs while the
/// native splash is still on screen, so the user never sees onboarding or
/// sign-in flash past on the way to where they actually belong.
class StartupState {
  const StartupState({
    required this.firebaseStatus,
    required this.prefs,
    required this.signedIn,
    required this.onboardingCompleted,
  });

  final FirebaseStatus firebaseStatus;
  final SharedPreferences prefs;
  final bool signedIn;
  final bool onboardingCompleted;

  String get initialRoute {
    if (signedIn) return entryPointScreenRoute;
    if (onboardingCompleted) return logInScreenRoute;
    return onbordingScreenRoute;
  }
}

Future<StartupState> bootstrapApp() async {
  final results = await Future.wait([
    bootstrapFirebase(),
    SharedPreferences.getInstance(),
  ]);
  final firebaseStatus = results[0] as FirebaseStatus;
  final prefs = results[1] as SharedPreferences;

  final signedIn =
      firebaseStatus == FirebaseStatus.ready && await _restoredUser() != null;

  return StartupState(
    firebaseStatus: firebaseStatus,
    prefs: prefs,
    signedIn: signedIn,
    // A signed-in user has, by definition, been through onboarding — this
    // also covers sessions from builds before the flag existed.
    onboardingCompleted: signedIn || LocalStore(prefs).onboardingCompleted,
  );
}

/// On Android the plugin hands Dart the persisted user during
/// `Firebase.initializeApp`, so `currentUser` is normally already set. The
/// stream fallback (bounded) only matters on platforms that restore later.
Future<User?> _restoredUser() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return auth.currentUser;
  try {
    return await auth.authStateChanges().first.timeout(const Duration(seconds: 3));
  } catch (_) {
    return auth.currentUser;
  }
}
