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

  /// Height of the floating bottom navigation bar.
  static const double navBarHeight = 64;

  /// Gap between the floating nav bar and the bottom of the screen (on top
  /// of the system inset).
  static const double navFloatGap = 12;

  /// Bottom padding for scrollables in the tab shell (content runs under the
  /// floating nav) and lists the WhatsApp button floats over — lets the last
  /// item scroll fully clear of both. Add the system bottom inset on top.
  static const double fabClearance = navBarHeight + navFloatGap + 72;
}
