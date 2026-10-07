import 'package:flutter/material.dart';

/// Legacy light-only shadows. New code reads the theme-aware
/// `context.colors.shadowCard / shadowRaised / shadowFloating`, which drop to
/// borders in dark mode.
abstract final class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F222222), offset: Offset(0, 2), blurRadius: 10),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A222222), offset: Offset(0, 12), blurRadius: 28),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x24222222), offset: Offset(0, 24), blurRadius: 56),
  ];
}
