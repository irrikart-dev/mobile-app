import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/core/theme/app_theme.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/route/router.dart' as router;

void main() {
  runApp(const ProviderScope(child: IrriKartApp()));
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
