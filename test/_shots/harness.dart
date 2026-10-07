import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/firebase/firebase_bootstrap.dart';
import 'package:irrikart/core/storage/local_store.dart';
import 'package:irrikart/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> loadShotFonts() async {
  const dir = 'assets/fonts/plus_jakarta_sans';
  await _font('Plus Jakarta Sans', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      '$dir/PlusJakartaSans-$w.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  await _font('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

/// Pumps [child] full-screen on a 390x844 @3x phone and writes a PNG.
Future<void> shot(
  WidgetTester tester,
  String name,
  Widget child, {
  bool dark = false,
  List<Override> overrides = const [],
  Duration settle = const Duration(milliseconds: 800),
  Future<void> Function(WidgetTester tester)? before,
}) async {
  // flutter_test draws shadows unblurred by default; show them as on device.
  debugDisableShadows = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 60);
  tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 60);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWithValue(FirebaseStatus.notConfigured),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump(settle);
  if (before != null) await before(tester);
  await tester.pump(settle);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name${dark ? '_dark' : ''}.png'),
  );
  // Tear down so periodic timers (carousels, shimmer) don't leak.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
  debugDisableShadows = true;
}
