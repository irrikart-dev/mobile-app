import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Outcome of the one-shot Firebase initialisation done in `main()`.
enum FirebaseStatus {
  /// Firebase is live; email/password sign-in works.
  ready,

  /// `firebase_options.dart` still holds the checked-in placeholders.
  notConfigured,

  /// Real config, but `Firebase.initializeApp` threw (bad values, no network
  /// on a cold start, misconfigured bundle id).
  failed,
}

/// Initialises Firebase without ever taking the app down with it.
///
/// A farmer opening the app on a patchy connection must still reach the
/// catalogue, so a Firebase failure degrades to "authentication unavailable"
/// rather than a crash on the launch screen.
Future<FirebaseStatus> bootstrapFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'IrriKart: Firebase is not configured — run `flutterfire configure`. '
      'Sign-in is disabled; the rest of the app works.',
    );
    return FirebaseStatus.notConfigured;
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirebaseStatus.ready;
  } catch (error, stackTrace) {
    debugPrint('IrriKart: Firebase failed to initialise — $error');
    debugPrintStack(stackTrace: stackTrace);
    return FirebaseStatus.failed;
  }
}
