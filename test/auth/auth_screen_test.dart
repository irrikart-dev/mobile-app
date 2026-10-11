import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/firebase/firebase_bootstrap.dart';
import 'package:irrikart/core/storage/local_store.dart';
import 'package:irrikart/screens/auth/views/auth_screen.dart';
import 'package:irrikart/screens/auth/views/components/otp_code_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends Fake implements AuthService {
  int phoneRequests = 0;
  int googleRequests = 0;
  String? lastPhone;

  @override
  bool get isAvailable => true;

  @override
  Stream<PhoneAuthEvent> verifyPhoneNumber(
    String phoneNumber, {
    int? resendToken,
  }) {
    phoneRequests++;
    lastPhone = phoneNumber;
    return Stream.value(const OtpSent('vid', 7));
  }

  @override
  Future<Never> signInWithGoogle() async {
    googleRequests++;
    throw const AuthException('nope', code: 'operation-not-allowed');
  }
}

Future<(_FakeAuth, SharedPreferences)> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final auth = _FakeAuth();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWithValue(FirebaseStatus.ready),
        sharedPreferencesProvider.overrideWithValue(sp),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: const MaterialApp(home: AuthScreen()),
    ),
  );
  await tester.pump();
  return (auth, sp);
}

void main() {
  testWidgets('methods are locked until the terms are accepted', (t) async {
    final (auth, sp) = await _pump(t);
    expect(find.text('Please accept to continue'), findsNothing);

    await t.tap(find.text('Continue with Google'));
    await t.pump(const Duration(seconds: 1));
    expect(auth.googleRequests, 0);
    expect(find.text('Please accept to continue'), findsOneWidget);

    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(find.text('Please accept to continue'), findsNothing);
    expect(LocalStore(sp).termsAcceptedAt, isNotNull);

    await t.tap(find.text('Continue with Google'));
    await t.pump();
    expect(auth.googleRequests, 1);
    // operation-not-allowed surfaces as friendly copy, not a crash.
    expect(find.text('nope'), findsOneWidget);
  });

  testWidgets('returning users see the terms pre-ticked', (t) async {
    await _pump(
      t,
      prefs: {'terms_accepted_at': DateTime(2026).toIso8601String()},
    );
    final box = t.widget<Checkbox>(find.byType(Checkbox));
    expect(box.value, isTrue);
  });

  testWidgets('phone path validates, sends the OTP and shows the code step',
      (t) async {
    final (auth, _) = await _pump(
      t,
      prefs: {'terms_accepted_at': DateTime(2026).toIso8601String()},
    );

    await t.enterText(find.byType(TextFormField).first, '12345');
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(auth.phoneRequests, 0);
    expect(find.text('Enter all 10 digits of your number'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).first, '9876543210');
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(auth.lastPhone, '+919876543210');
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.textContaining('Resend in 0:'), findsOneWidget);

    await t.pump(const Duration(seconds: 31));
    expect(find.text('Resend code'), findsOneWidget);

    await t.tap(find.text('Change number'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(OtpCodeField), findsNothing);
  });
}
