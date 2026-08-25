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
}
