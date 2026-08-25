/// Animation durations.
///
/// [normal] is 300ms — the template's `defaultDuration`.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  /// Debounce window for the search field.
  static const Duration searchDebounce = Duration(milliseconds: 350);
}
