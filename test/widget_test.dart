import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/firebase/firebase_bootstrap.dart';
import 'package:irrikart/core/startup/app_bootstrap.dart';
import 'package:irrikart/core/storage/local_store.dart';
import 'package:irrikart/main.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/screens/onbording/views/onbording_screnn.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the onboarding screen without throwing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseStatusProvider.overrideWithValue(FirebaseStatus.notConfigured),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const IrriKartApp(initialRoute: onbordingScreenRoute),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(OnBordingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('startup routing', () {
    Future<StartupState> state({required bool signedIn, required bool onboarded}) async {
      SharedPreferences.setMockInitialValues({});
      return StartupState(
        firebaseStatus: FirebaseStatus.ready,
        prefs: await SharedPreferences.getInstance(),
        signedIn: signedIn,
        onboardingCompleted: onboarded,
      );
    }

    test('signed in goes straight to the app', () async {
      expect((await state(signedIn: true, onboarded: true)).initialRoute, entryPointScreenRoute);
    });

    test('returning signed-out user goes to sign-in, not onboarding', () async {
      expect((await state(signedIn: false, onboarded: true)).initialRoute, logInScreenRoute);
    });

    test('brand-new install sees onboarding', () async {
      expect((await state(signedIn: false, onboarded: false)).initialRoute, onbordingScreenRoute);
    });
  });

  test('onboarding flag persists', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    expect(store.onboardingCompleted, isFalse);
    await store.markOnboardingCompleted();
    expect(LocalStore(await SharedPreferences.getInstance()).onboardingCompleted, isTrue);
  });
}
