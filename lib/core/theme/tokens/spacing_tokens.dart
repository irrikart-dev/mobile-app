/// Spacing scale (4-pt grid). Every gap, pad and inset should come from here.
///
/// 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double mdPlus = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xlPlus = 40;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Horizontal page margin on every screen.
  static const double gutter = 16;

  /// Vertical rhythm between home-screen sections.
  static const double sectionGap = 28;

  /// Legacy: full-section padding used by older home widgets.
  static const double sectionPy = 40;

  /// Card interior padding.
  static const double cardPad = 16;

  /// Height of the bottom navigation bar, excluding the system inset.
  static const double navBarHeight = 64;

  /// Bottom padding for scrollables that the floating WhatsApp button can sit
  /// over (tab roots, lists) — lets the last item scroll clear of it.
  static const double fabClearance = 84;
}
