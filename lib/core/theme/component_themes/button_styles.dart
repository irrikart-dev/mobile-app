import 'package:flutter/material.dart';

/// Button styles for cases the global theme's defaults don't fit.
abstract final class AppButtonStyles {
  /// Use this for **any button sitting inside a `Row`**.
  ///
  /// The app-wide `ElevatedButtonTheme`/`OutlinedButtonTheme` set
  /// `minimumSize: Size(double.infinity, 48)` so buttons fill their column by
  /// default — that's the full-width pill look everywhere else. `minimumSize`
  /// becomes a `ConstrainedBox(minWidth: infinity)`, which is harmless under a
  /// *bounded* parent: infinity clamps down to the available width.
  ///
  /// A `Row` is the exception. It lays non-flex children out with an unbounded
  /// main-axis constraint, so nothing clamps that infinity — the button
  /// reports infinite width, `RenderFlex` computes free space as
  /// `maxWidth - infinity == 0`, every `Expanded` sibling collapses to zero
  /// width (text then wraps one glyph per line), and the button itself is
  /// clipped away entirely. That failure is silent in release builds.
  ///
  /// This drops the width floor back to zero so the button hugs its label.
  /// Height stays at 48 to match every other button in the app.
  static final ButtonStyle inline = ElevatedButton.styleFrom(
    minimumSize: const Size(0, 48),
  );
}
