@Tags(['shots'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/screens/auth/views/auth_screen.dart';
import 'package:irrikart/screens/auth/views/components/otp_code_field.dart';
import 'package:irrikart/screens/auth/views/components/terms_consent.dart';
import 'package:irrikart/screens/profile/views/account_providers.dart';
import 'package:irrikart/screens/user_info/views/user_info_screen.dart';

import 'harness.dart';

/// Firebase isn't configured in the harness; this stands in so the sign-in
/// methods render enabled and the phone step can advance to the OTP screen.
class _FakeAuth extends Fake implements AuthService {
  @override
  bool get isAvailable => true;

  @override
  Stream<PhoneAuthEvent> verifyPhoneNumber(
    String phoneNumber, {
    int? resendToken,
  }) =>
      Stream.value(const OtpSent('verification-id', 1));
}

class _PhoneProvider extends Fake implements UserInfo {
  @override
  String get providerId => 'phone';
}

class _PhoneUser extends Fake implements User {
  @override
  String? get displayName => null;
  @override
  String? get email => null;
  @override
  String? get phoneNumber => '+919876543210';
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => [_PhoneProvider()];
}

/// Shows [child] as a pushed route so it gets a real back button.
class _Pushed extends StatefulWidget {
  const _Pushed(this.child);

  final Widget child;

  @override
  State<_Pushed> createState() => _PushedState();
}

class _PushedState extends State<_Pushed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => widget.child),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

final _available = [authServiceProvider.overrideWithValue(_FakeAuth())];

Future<void> _tickTerms(WidgetTester t) async {
  await t.tap(find.byType(Checkbox));
  await t.pump();
}

Future<void> _toOtpStep(WidgetTester t) async {
  await _tickTerms(t);
  await t.enterText(find.byType(TextFormField).first, '9876543210');
  await t.tap(find.text('Continue'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.enterText(
    find.descendant(
      of: find.byType(OtpCodeField),
      matching: find.byType(TextField),
    ),
    '4821',
  );
  await t.pump(const Duration(seconds: 4));
}

void main() {
  setUpAll(loadShotFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'auth default $dark',
      (t) => shot(
        t,
        'auth_default',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
      ),
    );
    testWidgets(
      'auth ticked $dark',
      (t) => shot(
        t,
        'auth_ticked',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: (t) async {
          await _tickTerms(t);
          await t.enterText(find.byType(TextFormField).first, '98765');
          await t.pump();
        },
      ),
    );
    testWidgets(
      'auth nudge $dark',
      (t) => shot(
        t,
        'auth_nudge',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: (t) async {
          await t.tap(find.text('Continue with Google'));
          await t.pump(const Duration(seconds: 1));
          expect(find.text('Please accept to continue'), findsOneWidget);
          expect(find.byType(TermsConsent), findsOneWidget);
        },
      ),
    );
    testWidgets(
      'auth otp $dark',
      (t) => shot(
        t,
        'auth_otp',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: _toOtpStep,
      ),
    );
    testWidgets(
      'auth email $dark',
      (t) => shot(
        t,
        'auth_email',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: (t) async {
          await _tickTerms(t);
          await t.tap(find.text('Continue with email'));
          await t.pump();
          await t.pump(const Duration(seconds: 1));
        },
      ),
    );
    testWidgets(
      'auth email signup $dark',
      (t) => shot(
        t,
        'auth_email_signup',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: (t) async {
          await _tickTerms(t);
          await t.tap(find.text('Continue with email'));
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          await t.tap(find.text('Create an account'));
          await t.pump();
          await t.pump(const Duration(seconds: 1));
        },
      ),
    );
    testWidgets(
      'auth email forgot $dark',
      (t) => shot(
        t,
        'auth_email_forgot',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: (t) async {
          await _tickTerms(t);
          await t.tap(find.text('Continue with email'));
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          await t.tap(find.text('Forgot password?'));
          await t.pump();
          await t.pump(const Duration(seconds: 1));
        },
      ),
    );
    testWidgets(
      'auth unavailable $dark',
      (t) => shot(t, 'auth_unavailable', const AuthScreen(), dark: dark),
    );
    testWidgets(
      'auth small keyboard $dark',
      (t) => shot(
        t,
        'auth_small_keyboard',
        const AuthScreen(),
        dark: dark,
        overrides: _available,
        before: (t) async {
          // 360 x 640 dp phone with a ~300 dp keyboard up.
          addTearDown(t.view.reset);
          t.view.physicalSize = const Size(1080, 1920);
          t.view.padding = const FakeViewPadding(top: 72);
          t.view.viewPadding = const FakeViewPadding(top: 72);
          await t.pump();
          await t.showKeyboard(find.byType(TextFormField).first);
          await t.enterText(find.byType(TextFormField).first, '98765');
          t.view.viewInsets = const FakeViewPadding(bottom: 900);
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          await t.pump(const Duration(milliseconds: 400));
          expect(t.takeException(), isNull);
        },
      ),
    );
    testWidgets(
      'details phone user $dark',
      (t) => shot(
        t,
        'details_phone',
        const _Pushed(UserInfoScreen()),
        dark: dark,
        overrides: [
          accountUserProvider.overrideWith((ref) => Stream.value(_PhoneUser())),
          authStateProvider.overrideWith((ref) => Stream.value(_PhoneUser())),
        ],
      ),
    );
  }
}
