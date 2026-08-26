import 'package:flutter/widgets.dart';

/// Corner radius scale, matched to the "Botanical Classic" reference theme's
/// `--radius-sm/md/lg/pill` (10 / 16 / 26 / 999).
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 26;
  static const double xl = 32;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
