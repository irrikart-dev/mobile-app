import 'dart:async';
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
/// an ID token whose audience Firebase accepts. Not a secret: safe to ship in
/// the client, same as any other OAuth client id.
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

/// One step of a phone-number verification started with
/// [AuthService.verifyPhoneNumber].
sealed class PhoneAuthEvent {
  const PhoneAuthEvent();
}

/// The SMS went out; the user now types the code it carries.
final class OtpSent extends PhoneAuthEvent {
  const OtpSent(this.verificationId, this.resendToken);

  final String verificationId;

  /// Pass back to [AuthService.verifyPhoneNumber] for "Resend code" so
  /// Android doesn't make the user solve another reCAPTCHA.
  final int? resendToken;
}

/// Android read the SMS by itself — the code, for the OTP boxes to show
/// while the automatic sign-in that follows is in flight.
final class OtpAutoFilled extends PhoneAuthEvent {
  const OtpAutoFilled(this.smsCode);

  final String smsCode;
}

/// Signed in without the user typing anything (Android instant verification
/// or SMS auto-retrieval).
final class OtpAutoSignedIn extends PhoneAuthEvent {
  const OtpAutoSignedIn();
}

final class OtpFailed extends PhoneAuthEvent {
  const OtpFailed(this.error);

  final AuthException error;
}

/// Wraps every sign-in method — phone OTP, email + password and Google — so
/// no screen touches FirebaseAuth or GoogleSignIn directly and every failure
/// arrives as a farmer-readable [AuthException].
class AuthService {
  AuthService(this._status, [GoogleSignIn? googleSignIn])
      : _googleSignIn =
            googleSignIn ?? GoogleSignIn(serverClientId: _googleWebClientId);

  final FirebaseStatus _status;
  final GoogleSignIn _googleSignIn;

  bool get isAvailable => _status == FirebaseStatus.ready;

  User? get currentUser =>
      isAvailable ? FirebaseAuth.instance.currentUser : null;

  FirebaseAuth get _auth {
    if (!isAvailable) throw const AuthUnavailableException();
    return FirebaseAuth.instance;
  }

  /// Both new and returning users go through the same call — Firebase
  /// creates the account on first sign-in and just authenticates it every
  /// time after. Google has already verified the email, so nothing else
  /// (a password, an OTP) is needed.
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

  // ---------------------------------------------------------------------
  // Phone number + OTP
  // ---------------------------------------------------------------------

  /// Sends an OTP to [phoneNumber] (E.164, e.g. `+919876543210`) and reports
  /// progress as a stream: usually [OtpSent], then nothing until the
  /// user types the code into [confirmSmsCode]. On Android the stream may
  /// instead (or additionally) emit [OtpAutoFilled] + [OtpAutoSignedIn]
  /// when Play services verifies the number or reads the SMS itself.
  ///
  /// Cancel the subscription to stop listening (e.g. "Change number").
  Stream<PhoneAuthEvent> verifyPhoneNumber(
    String phoneNumber, {
    int? resendToken,
  }) {
    if (!isAvailable) throw const AuthUnavailableException();
    late final StreamController<PhoneAuthEvent> controller;
    void emit(PhoneAuthEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    controller = StreamController<PhoneAuthEvent>(
      onListen: () {
        _auth
            .verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            final code = credential.smsCode;
            if (code != null) emit(OtpAutoFilled(code));
            try {
              await _guard(() => _auth.signInWithCredential(credential));
              emit(const OtpAutoSignedIn());
            } on AuthException catch (e) {
              emit(OtpFailed(e));
            }
          },
          verificationFailed: (e) => emit(
            OtpFailed(
              AuthException(messageFor(e.code), code: e.code),
            ),
          ),
          codeSent: (id, token) => emit(OtpSent(id, token)),
          // Auto-retrieval gave up — the user simply types the code.
          codeAutoRetrievalTimeout: (_) {},
        )
            .catchError((Object e) {
          final code = e is FirebaseAuthException ? e.code : null;
          emit(OtpFailed(AuthException(messageFor(code), code: code)));
        });
      },
      onCancel: () => controller.close(),
    );
    return controller.stream;
  }

  /// Signs in with the 6-digit [smsCode] the user typed.
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _guard(() => _auth.signInWithCredential(credential));
  }

  // ---------------------------------------------------------------------
  // Email + password
  // ---------------------------------------------------------------------

  Future<void> signInWithEmail(String email, String password) => _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  /// Creates the Firebase account and signs it in. [displayName], when
  /// given, is set on the Firebase profile; the backend copy is written by
  /// the caller once `/auth/firebase/sync` has created the user row.
  Future<void> createAccountWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final credential = await _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    final name = displayName?.trim();
    final user = credential.user;
    if (user != null && name != null && name.isNotEmpty) {
      // Best-effort: the account exists either way, and the name can be
      // edited from "Your details" later.
      try {
        await user.updateDisplayName(name);
        await user.reload();
      } on FirebaseAuthException catch (_) {}
    }
  }

  /// Emails a password-reset link. With Firebase's email-enumeration
  /// protection on, this succeeds even for an address with no account.
  Future<void> sendPasswordResetEmail(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  /// True from an explicit sign-out until the app has handled it — lets the
  /// session-ended listener tell "user tapped Log out" apart from "Firebase
  /// dropped the session" (revoked/expired), which deserves a message.
  static bool explicitSignOutPending = false;

  Future<void> signOut() async {
    explicitSignOutPending = true;
    // Also clears Google's cached account, so the next sign-in shows the
    // account picker instead of silently reusing the last account.
    await _googleSignIn.signOut().catchError((_) => null);
    await _guard(() => _auth.signOut());
  }

  /// Runs [action], translating Firebase's error codes into user-facing copy.
  Future<T> _guard<T>(Future<T> Function() action) async {
    if (!isAvailable) throw const AuthUnavailableException();
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e), code: e.code);
    }
  }

  static String _messageFor(FirebaseAuthException e) => messageFor(e.code);

  /// Friendly copy for a Firebase Auth error [code]. Public so the mapping
  /// can be unit-tested and reused by screens.
  static String messageFor(String? code) {
    switch (code) {
      // --- configuration ---
      case 'operation-not-allowed':
        return 'This sign-in method isn’t enabled yet. Please use another '
            'option or try again later.';
      // --- email + password ---
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'That email and password don’t match. Check them and try '
            'again, or reset your password.';
      case 'user-not-found':
        return 'No account found with this email. Create one instead?';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Choose a stronger password — at least 8 characters, mixing '
            'letters and numbers.';
      case 'invalid-email':
        return 'That email address doesn’t look right.';
      // --- phone + OTP ---
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'That mobile number doesn’t look right. Check it and try '
            'again.';
      case 'invalid-verification-code':
      case 'missing-verification-code':
        return 'That code isn’t right. Check the SMS and try again.';
      case 'session-expired':
      case 'code-expired':
      case 'invalid-verification-id':
      case 'missing-verification-id':
        return 'This code has expired. Tap “Resend code” to get a new one.';
      case 'billing-not-enabled':
        return 'SMS sign-in isn’t available right now. Please continue with '
            'Google or email.';
      case 'quota-exceeded':
        return 'We can’t send more codes right now. Please try again later, '
            'or continue with Google or email.';
      case 'captcha-check-failed':
      case 'missing-client-identifier':
      case 'app-not-authorized':
      case 'invalid-app-credential':
      case 'missing-app-credential':
      case 'web-context-cancelled':
        return 'We couldn’t verify this device for SMS sign-in. Please try '
            'again, or continue with Google or email.';
      case 'credential-already-in-use':
        return 'This number is already linked to another account.';
      // --- shared ---
      case 'user-disabled':
        return 'This account has been disabled. Contact IrriKart support.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered a different way.';
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
        return 'Google sign-in could not start. Please try again shortly.';
      default:
        return 'Could not sign in with Google. Please try again.';
    }
  }
}
