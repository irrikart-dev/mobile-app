import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Shown on the auth screen when Firebase is not configured or failed to
/// initialise.
class AuthUnavailableNotice extends StatelessWidget {
  const AuthUnavailableNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const InlineBanner(
      tone: Tone.warning,
      title: 'Sign-in is not available yet',
      message: 'This build has no Firebase configuration. Browsing the '
          'catalogue works as normal.',
    );
  }
}
