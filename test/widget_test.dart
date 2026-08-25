import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/main.dart';
import 'package:irrikart/screens/onbording/views/onbording_screnn.dart';

void main() {
  testWidgets('app boots to the onboarding screen without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: IrriKartApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(OnBordingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
