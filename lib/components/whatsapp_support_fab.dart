import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/auth/auth_service.dart';
import '../core/utils/whatsapp_launcher.dart';

/// Persistent floating WhatsApp contact button. Mounted once at the app root
/// (see `IrriKartApp`'s `MaterialApp.builder`) so it survives every push/pop
/// across the whole navigator stack — home, listings, PDP, cart, everywhere —
/// rather than being re-added screen by screen.
///
/// Hidden until the user is signed in: splash/onboarding/auth screens render
/// underneath this before there's an account to route a support chat to, so
/// showing it there would just be a floating button with nothing behind it.
class WhatsAppSupportFab extends ConsumerWidget {
  const WhatsAppSupportFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 88,
      child: SafeArea(
        child: FloatingActionButton(
          heroTag: 'whatsapp_support_fab',
          backgroundColor: const Color(0xFF25D366),
          onPressed: () => openWhatsAppSupport(context),
          child: const HugeIcon(icon: HugeIcons.strokeRoundedWhatsapp, color: Colors.white),
        ),
      ),
    );
  }
}
