import 'package:flutter/material.dart';

/// Soft, low-contrast shadows — matched to the "Botanical Classic" reference
/// theme's `--shadow-sm/md/lg` (`0 Npx Mpx #2222220f/1a/24`).
///
/// Prefer these over `CardTheme`'s `elevation`; Material's default elevation
/// shadow is too dark and too tight for this design language.
abstract final class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F222222), offset: Offset(0, 2), blurRadius: 10),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A222222),
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x24222222),
      offset: Offset(0, 24),
      blurRadius: 56,
    ),
  ];
}
