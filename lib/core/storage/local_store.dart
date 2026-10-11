import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolved once in `bootstrapApp()` and injected via a `ProviderScope`
/// override, so everything below can read preferences synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

/// Device-local, non-sensitive app state. Auth/session state is never stored
/// here — Firebase owns that.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingDone = 'onboarding_completed';
  static const _themeMode = 'theme_mode';
  static const _wishlist = 'wishlist_slugs';
  static const _recentSearches = 'recent_searches';
  static const _recentlyViewed = 'recently_viewed_slugs';
  static const _termsAcceptedAt = 'terms_accepted_at';

  /// When the Terms & Conditions / Privacy Policy box was ticked on the
  /// sign-in screen on this device (null = not accepted). Device-level, so a
  /// returning user sees it pre-ticked even after logging out.
  DateTime? get termsAcceptedAt {
    final raw = _prefs.getString(_termsAcceptedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setTermsAcceptedAt(DateTime? at) => at == null
      ? _prefs.remove(_termsAcceptedAt)
      : _prefs.setString(_termsAcceptedAt, at.toUtc().toIso8601String());

  bool get onboardingCompleted => _prefs.getBool(_onboardingDone) ?? false;
  Future<void> markOnboardingCompleted() => _prefs.setBool(_onboardingDone, true);
  Future<void> resetOnboarding() => _prefs.remove(_onboardingDone);

  ThemeMode get themeMode => switch (_prefs.getString(_themeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString(_themeMode, mode.name);

  Set<String> get wishlist => (_prefs.getStringList(_wishlist) ?? const []).toSet();
  Future<void> setWishlist(Set<String> slugs) => _prefs.setStringList(_wishlist, slugs.toList());

  List<String> get recentSearches => _prefs.getStringList(_recentSearches) ?? const [];
  Future<void> setRecentSearches(List<String> terms) =>
      _prefs.setStringList(_recentSearches, terms);

  /// Wipes everything tied to the person using the device (not app-level
  /// settings like theme or onboarding) — used after account deletion.
  Future<void> clearPersonalData() async {
    await _prefs.remove(_wishlist);
    await _prefs.remove(_recentSearches);
    await _prefs.remove(_recentlyViewed);
  }

  List<String> get recentlyViewed => _prefs.getStringList(_recentlyViewed) ?? const [];
  Future<void> setRecentlyViewed(List<String> slugs) =>
      _prefs.setStringList(_recentlyViewed, slugs);

  static const _guestCart = 'guest_cart_v1';

  /// The signed-out cart: one JSON map per line (`variantId`, `quantity`
  /// plus the display fields `CartController` snapshots from the
  /// catalogue). Merged into the server cart and cleared on sign-in.
  List<Map<String, dynamic>> get guestCart {
    final raw = _prefs.getString(_guestCart);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const []; // corrupt — start over rather than crash
    }
  }

  Future<void> setGuestCart(List<Map<String, dynamic>> lines) => lines.isEmpty
      ? _prefs.remove(_guestCart)
      : _prefs.setString(_guestCart, jsonEncode(lines));
}
