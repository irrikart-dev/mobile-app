import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_validators.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/storage/local_store.dart';
import '../../../models/wishlist_state.dart';

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

/// Best display name for [user]: profile name, else the email's local part,
/// else the phone number (phone-OTP accounts have neither name nor email).
String accountDisplayName(User? user) {
  final name = user?.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = user?.email;
  if (email != null && email.contains('@')) return email.split('@').first;
  final phone = user?.phoneNumber;
  if (phone != null && phone.isNotEmpty) {
    return AuthValidators.formatPhone(phone);
  }
  return 'IrriKart customer';
}

/// Up to two initials from [name], e.g. "Ravi Kumar" → "RK". A name with
/// no letters at all (the phone-number fallback) gets the IrriKart "IK".
String accountInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final worded =
      parts.where((p) => RegExp(r'^\p{L}', unicode: true).hasMatch(p)).toList();
  if (worded.isEmpty) return 'IK';
  final first = String.fromCharCode(worded.first.runes.first);
  final last =
      worded.length > 1 ? String.fromCharCode(worded.last.runes.first) : '';
  return (first + last).toUpperCase();
}

/// Permanently deletes the signed-in account (`DELETE /auth/account`), then
/// clears this device: Firebase/Google session and locally stored wishlist,
/// searches and recently viewed. Throws on failure, leaving everything as-is.
Future<void> deleteAccount(WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  await apiRequest(() => dio.delete<dynamic>('/auth/account'), (_) {});

  await ref.read(localStoreProvider).clearPersonalData();
  ref
    ..invalidate(wishlistControllerProvider)
    ..invalidate(recentlyViewedProvider)
    ..invalidate(recentSearchesProvider);
  // The Firebase user no longer exists server-side; this just drops the
  // local session and Google's cached account.
  await ref.read(authServiceProvider).signOut().catchError((_) {});
}

/// `POST /auth/logout-all`, then drops this device's session. The server
/// also forgets every push device, so no unregister call is needed.
Future<void> logoutAllDevices(WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  await apiRequest(() => dio.post<dynamic>('/auth/logout-all'), (_) {});
  await ref.read(authServiceProvider).signOut().catchError((_) {});
}
