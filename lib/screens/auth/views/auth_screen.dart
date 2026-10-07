import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/config/support_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/tokens/color_tokens.dart';
import '../../../route/route_constants.dart';
import 'components/auth_unavailable_notice.dart';
import 'components/google_sign_in_button.dart';

/// The app's single entry point into an account — Google Sign-In only.
///
/// Serves both `logInScreenRoute` and `signUpScreenRoute`: Firebase creates
/// the account on a Google account's first sign-in and just authenticates it
/// every time after. Built to take an Apple button under Google's without
/// reshuffling anything.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _continueWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted || credential == null) return; // null = picker was closed

      // Signed-in users never see onboarding again, even after a later log-out.
      unawaited(ref.read(localStoreProvider).markOnboardingCompleted());

      // Mirrors the Firebase account into the backend's own User table —
      // cart/orders 401 with "No account linked" until this has run once.
      // Best-effort: the Dio interceptor retries this itself on the next
      // authenticated call if it doesn't land here for any reason.
      unawaited(ref.read(dioProvider).post<dynamic>('/auth/firebase/sync'));

      unawaited(
        Navigator.pushNamedAndRemoveUntil(
          context,
          entryPointScreenRoute,
          (route) => false,
        ),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } on AuthUnavailableException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAvailable = ref.watch(authServiceProvider).isAvailable;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Hero(),
                  Expanded(
                    child: _SignInPanel(
                      authAvailable: authAvailable,
                      busy: _busy,
                      error: _error,
                      onContinueWithGoogle: _continueWithGoogle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand-gradient header: wordmark, headline, soft decorative circles.
/// White-on-gradient is the one place the brand colours carry the screen;
/// it reads the same in light and dark mode on purpose.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const onHero = AppColors.white;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          top + AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xlPlus,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.secondaryDark],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: _Circle(size: 220, color: onHero.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: _Circle(size: 200, color: onHero.withValues(alpha: 0.08)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: onHero.withValues(alpha: 0.16),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Image.asset(
                        'assets/logo/irrikart_logo_mark.png',
                        color: onHero,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Text(
                      'IrriKart',
                      style: context.text.h2.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Everything your farm needs, one tap away.',
                  style: context.text.display.copyWith(color: onHero),
                ),
                const SizedBox(height: AppSpacing.smd),
                Text(
                  'Pumps, drip irrigation and farm tools from brands you trust.',
                  style: context.text.body.copyWith(
                    color: onHero.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({
    required this.authAvailable,
    required this.busy,
    required this.error,
    required this.onContinueWithGoogle,
  });

  final bool authAvailable;
  final bool busy;
  final String? error;
  final VoidCallback onContinueWithGoogle;

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final linkStyle = context.text.caption.copyWith(
      color: c.textPrimary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: c.textMuted,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ValueProp(
              icon: Icons.verified_outlined,
              title: 'Genuine products',
              subtitle: 'Sourced directly from trusted brands',
            ),
            const _ValueProp(
              icon: Icons.local_shipping_outlined,
              title: 'Delivered across India',
              subtitle: 'Track every order to your doorstep',
            ),
            const _ValueProp(
              icon: Icons.lock_outline_rounded,
              title: 'Secure prepaid checkout',
              subtitle: 'UPI, cards and netbanking via Razorpay',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!authAvailable) ...[
              const AuthUnavailableNotice(),
              const SizedBox(height: AppSpacing.md),
            ],
            GoogleSignInButton(
              busy: busy,
              onPressed: authAvailable ? onContinueWithGoogle : null,
            ),
            AnimatedSize(
              duration: AppDurations.fast,
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.smd),
                      child: InlineBanner(message: error!, tone: Tone.error),
                    ),
            ),
            const Spacer(),
            const SizedBox(height: AppSpacing.lg),
            Text.rich(
              TextSpan(
                text: 'By continuing, you agree to IrriKart’s ',
                style: context.text.caption,
                children: [
                  TextSpan(
                    text: 'Terms of Service',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _open(SupportConfig.termsUrl),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _open(SupportConfig.privacyUrl),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueProp extends StatelessWidget {
  const _ValueProp({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 20, color: c.onPrimarySoft),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.title),
                Text(subtitle, style: context.text.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
