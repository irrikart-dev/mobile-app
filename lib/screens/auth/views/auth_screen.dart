import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.forest,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _Hero()),
            _SignInSheet(
              authAvailable: authAvailable,
              busy: _busy,
              error: _error,
              onContinueWithGoogle: _continueWithGoogle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep-green top: the white IrriKart lockup and the geometric brand art.
/// Same in light and dark mode on purpose — it's the brand moment.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.forest, AppColors.forestDark],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          top + AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/logo/irrikart_logo_full_white.png',
              height: 72,
              semanticLabel: 'IrriKart',
            ),
            const SizedBox(height: AppSpacing.lg),
            const Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: GeoMosaic.columns / GeoMosaic.rows,
                  child: ClipRRect(
                    borderRadius: AppRadius.xlAll,
                    child: GeoMosaic(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded sheet overlapping the hero's bottom edge.
class _SignInSheet extends StatelessWidget {
  const _SignInSheet({
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
      fontWeight: FontWeight.w700,
    );

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: AppRadius.sheetTop,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome to IrriKart', style: context.text.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Genuine irrigation and farm gear, delivered to your field.',
            style: context.text.bodySecondary,
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
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                child: _Promise(
                  icon: Icons.verified_rounded,
                  label: 'Genuine brands',
                ),
              ),
              Expanded(
                child: _Promise(
                  icon: Icons.local_shipping_rounded,
                  label: 'Pan-India delivery',
                ),
              ),
              Expanded(
                child: _Promise(
                  icon: Icons.lock_rounded,
                  label: 'Secure payments',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text.rich(
            TextSpan(
              text: 'By continuing you agree to our ',
              style: context.text.caption,
              children: [
                TextSpan(
                  text: 'Terms',
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
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 22, color: c.accent),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.text.caption.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
