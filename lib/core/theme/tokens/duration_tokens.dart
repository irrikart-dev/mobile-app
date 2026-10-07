import 'package:flutter/animation.dart';

/// Animation durations.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  /// Debounce window for the search field.
  static const Duration searchDebounce = Duration(milliseconds: 350);
}

/// Motion curves. [standard] for most UI changes, [emphasized] for things
/// entering the screen, [press] for tap feedback.
abstract final class AppCurves {
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve press = Curves.easeOut;
}
