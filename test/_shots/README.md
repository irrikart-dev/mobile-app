# Screenshot harness

Renders screens at 390×844 @3x with the real fonts, light and dark, into
`test/_shots/out/` (git-ignored) for visual review.

    flutter test test/_shots --run-skipped -t shots --update-goldens

Skipped in normal `flutter test` runs (see `dart_test.yaml`).
