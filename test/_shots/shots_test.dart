@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/screens/auth/views/auth_screen.dart';
import 'package:irrikart/screens/onbording/views/onbording_screnn.dart';

import 'harness.dart';

void main() {
  setUpAll(loadShotFonts);
  for (final dark in [false, true]) {
    testWidgets('auth $dark', (t) => shot(t, 'auth', const AuthScreen(), dark: dark));
    testWidgets('onboarding $dark', (t) => shot(t, 'onboarding', const OnBordingScreen(), dark: dark));
  }
}
