import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/firebase/firebase_bootstrap.dart';

/// The signed-in user, re-emitting on profile edits too.
///
/// `authStateProvider` only fires on sign-in/out, so a display-name change
/// made on "Your details" would never reach the Account header. Firebase's
/// `userChanges()` also fires after `updateDisplayName` + `reload`.
final accountUserProvider = StreamProvider<User?>((ref) {
  if (ref.watch(firebaseStatusProvider) != FirebaseStatus.ready) {
    return Stream<User?>.value(null);
  }
  return ref.watch(firebaseAuthProvider).userChanges();
});

/// "1.4.0 (23)" — shown in the Account footer.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});

/// Best display name for [user]: profile name, else the email's local part.
String accountDisplayName(User? user) {
  final name = user?.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = user?.email;
  if (email != null && email.contains('@')) return email.split('@').first;
  return 'IrriKart customer';
}

/// Up to two initials from [name], e.g. "Ravi Kumar" → "RK".
String accountInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = String.fromCharCode(parts.first.runes.first);
  final last =
      parts.length > 1 ? String.fromCharCode(parts.last.runes.first) : '';
  return (first + last).toUpperCase();
}
