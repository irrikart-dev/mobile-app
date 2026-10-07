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

  List<String> get recentlyViewed => _prefs.getStringList(_recentlyViewed) ?? const [];
  Future<void> setRecentlyViewed(List<String> slugs) =>
      _prefs.setStringList(_recentlyViewed, slugs);
}
