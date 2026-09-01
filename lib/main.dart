import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/firebase/firebase_bootstrap.dart';
import 'package:irrikart/core/theme/app_theme.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/route/router.dart' as router;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved once, then read everywhere through `firebaseStatusProvider`.
  // A failure here does not stop the app: the catalogue stays browsable and
  // only the sign-in screens degrade. See `bootstrapFirebase`.
  final firebaseStatus = await bootstrapFirebase();

  runApp(
    ProviderScope(
      overrides: [firebaseStatusProvider.overrideWithValue(firebaseStatus)],
      child: const IrriKartApp(),
    ),
  );
}

class IrriKartApp extends StatelessWidget {
  const IrriKartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IrriKart',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      onGenerateRoute: router.generateRoute,
      initialRoute: onbordingScreenRoute,
    );
  }
}
