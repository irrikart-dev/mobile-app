import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class PasswordRecoveryScreen extends StatelessWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Forgot password',
      icon: Icons.lock_reset_outlined,
      title: 'Reset your password',
      message: 'Password reset over OTP lands with the authentication module.',
    );
  }
}
