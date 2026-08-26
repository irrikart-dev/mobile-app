/// Spacing scale. Every gap, pad and inset should come from here.
///
/// [md] is 16 — the template's `defaultPadding` — so existing layouts keep
/// their rhythm as they migrate off `constants.dart`.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Vertical padding for a full home-screen section. Matched to the
  /// reference theme's generous `--section-py: 6.5rem` on web; halved for a
  /// mobile viewport where that much whitespace would push content off-screen.
  static const double sectionPy = 40;

  /// Card interior padding, matched to the reference theme's `--card-pad`.
  static const double cardPad = 20;
}
