import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase/firebase_bootstrap.dart';
import '../firebase/firebase_options.dart';

/// Firebase's auto-provisioned **Web** OAuth client for this project. Passed
/// as `serverClientId` on every platform — that's what makes Google hand back
/// an ID token whose audience Firebase accepts, without a
/// `google-services.json` / `GoogleService-Info.plist` in the repo. Not a
/// secret: safe to ship in the client, same as any other OAuth client id.
const _googleWebClientId =
    '505911392963-1iute5rngd8foc7fqcmshkkoglmcab69.apps.googleusercontent.com';

/// Set once in `main()` from [bootstrapFirebase]. Overridden in `ProviderScope`.
final firebaseStatusProvider = Provider<FirebaseStatus>(
  (_) => throw UnimplementedError(
    'firebaseStatusProvider must be overridden in main()',
  ),
);

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  if (ref.watch(firebaseStatusProvider) != FirebaseStatus.ready) {
    throw const AuthUnavailableException();
  }
  return FirebaseAuth.instance;
});

/// The signed-in user, or null. Emits on sign-in, sign-out and token refresh.
final authStateProvider = StreamProvider<User?>((ref) {
  if (ref.watch(firebaseStatusProvider) != FirebaseStatus.ready) {
    return Stream<User?>.value(null);
  }
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Convenience: true once a user is signed in.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).valueOrNull != null,
);

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    serverClientId: _googleWebClientId,
    // iOS additionally needs its own client id — Google Sign-In won't
    // complete the redirect without it, even with serverClientId set.
    clientId: (!kIsWeb && Platform.isIOS)
        ? DefaultFirebaseOptions.ios.iosClientId
        : null,
  );
});

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(firebaseStatusProvider),
    ref.watch(googleSignInProvider),
  ),
);

/// Thrown when a sign-in is attempted while Firebase is not usable.
class AuthUnavailableException implements Exception {
  const AuthUnavailableException();

  String get userMessage =>
      'Sign-in is not available yet. Please try again later or contact support.';

  @override
  String toString() => 'AuthUnavailableException';
}

/// A failed sign-in, carrying a message that is safe to show a user.
class AuthException implements Exception {
  const AuthException(this.userMessage, {this.code});

  final String userMessage;
  final String? code;

  @override
  String toString() => 'AuthException($code): $userMessage';
}

/// Email/password authentication, wrapped so no screen touches FirebaseAuth
/// directly and every failure arrives as a farmer-readable [AuthException].
class AuthService {
  AuthService(this._status, [GoogleSignIn? googleSignIn])
      : _googleSignIn =
            googleSignIn ?? GoogleSignIn(serverClientId: _googleWebClientId);

  final FirebaseStatus _status;
  final GoogleSignIn _googleSignIn;

  /// Both new and returning users go through the same call — Firebase
  /// creates the account on first sign-in and just authenticates it every
  /// time after. Google has already verified the email, so this needs
  /// neither the OTP flow nor a password.
  ///
  /// Returns null if the user closed the account picker without choosing
  /// one — that's a change of mind, not a failure worth surfacing as an error.
  Future<UserCredential?> signInWithGoogle() async {
    if (!isAvailable) throw const AuthUnavailableException();

    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw AuthException(_messageForGoogle(e), code: e.code);
    }
    if (account == null) return null;

    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _guard(() => _auth.signInWithCredential(credential));
  }

  bool get isAvailable => _status == FirebaseStatus.ready;

  User? get currentUser =>
      isAvailable ? FirebaseAuth.instance.currentUser : null;

  FirebaseAuth get _auth {
    if (!isAvailable) throw const AuthUnavailableException();
    return FirebaseAuth.instance;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _guard(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  /// Signs into the account the backend just created, at the end of the
  /// OTP sign-up flow (see [SignupApi]). The backend proves the email was
  /// verified before creating anything, so there is no separate
  /// `createUserWithEmailAndPassword` call here — that would either race the
  /// server's account or throw `email-already-in-use` against it.
  Future<UserCredential> signInWithCustomToken(String token) =>
      _guard(() => _auth.signInWithCustomToken(token));

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> sendEmailVerification() => _guard(
        () => _auth.currentUser?.sendEmailVerification() ?? Future.value(),
      );

  /// Re-reads the user from the server — use after asking someone to click the
  /// verification link, since the cached `emailVerified` will still be false.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _guard(() => _auth.signOut());

  /// Runs [action], translating Firebase's error codes into user-facing copy.
  Future<T> _guard<T>(Future<T> Function() action) async {
    if (!isAvailable) throw const AuthUnavailableException();
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e), code: e.code);
    }
  }

  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      // Firebase returns `invalid-credential` for both a wrong password and an
      // unknown email when email enumeration protection is on (the default).
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Try logging in.';
      case 'weak-password':
        return 'Choose a stronger password — at least 8 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Contact IrriKart support.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this app yet.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered a different way. Try logging in with a password instead.';
      default:
        return 'Could not complete that request. Please try again.';
    }
  }

  static String _messageForGoogle(PlatformException e) {
    switch (e.code) {
      case GoogleSignIn.kNetworkError:
        return 'No internet connection. Check your network and try again.';
      case GoogleSignIn.kSignInFailedError:
        // On Android this is what a missing/mismatched SHA fingerprint
        // surfaces as — see docs/FIREBASE_SETUP.md.
        return 'Google sign-in could not start. Please try again or use your email instead.';
      default:
        return 'Could not sign in with Google. Please try again.';
    }
  }
}
