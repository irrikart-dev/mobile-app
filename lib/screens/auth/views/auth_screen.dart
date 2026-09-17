import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../route/route_constants.dart';
import 'components/auth_unavailable_notice.dart';
import 'components/google_sign_in_button.dart';

/// The app's single entry point into an account — Google Sign-In only.
///
/// Serves both `logInScreenRoute` and `signUpScreenRoute`: Firebase creates
/// the account on a Google account's first sign-in and just authenticates it
/// every time after, so there is nothing left to distinguish "log in" from
/// "sign up" at the UI layer. An Apple button is the next thing to land here
/// — [GoogleSignInButton] and this layout are built to take a second one
/// underneath without reshuffling anything.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              flex: 11,
              child: _Hero(isDark: isDark),
            ),
            Expanded(
              flex: 9,
              child: _SignInSheet(
                authAvailable: authAvailable,
                busy: _busy,
                error: _error,
                onContinueWithGoogle: _continueWithGoogle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand-gradient hero panel: logo, headline, a few soft decorative shapes.
/// No stock photography — nothing in the asset pack is on-brand for an
/// irrigation retailer, so the gradient and the client's own droplet mark
/// carry the visual weight instead.
class _Hero extends StatelessWidget {
  const _Hero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        scheme.primary.withValues(alpha: 0.85),
                        scheme.secondary.withValues(alpha: 0.85),
                      ]
                    : [scheme.primary, scheme.secondary],
              ),
            ),
          ),
          const Positioned(
            top: -60,
            right: -50,
            child: _Blob(size: 200, opacity: 0.14),
          ),
          const Positioned(
            bottom: -70,
            left: -60,
            child: _Blob(size: 220, opacity: 0.12),
          ),
          const Positioned(
            top: 60,
            left: -30,
            child: _Blob(size: 90, opacity: 0.10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    'assets/logo/irrikart_logo_mark.png',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Everything your\nfarm needs,\none tap away.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tools, pumps and irrigation kits from trusted brands.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Rounded sheet sitting over the hero's bottom edge, carrying the sign-in
/// controls. Elevation + a lightly overlapping negative margin is what makes
/// it read as a card rather than a second flat section.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Welcome', style: theme.textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign in to start shopping — your orders, wishlist and cart '
              'sync across every device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _ErrorBanner(error!),
            ],
            const Spacer(),
            Text.rich(
              TextSpan(
                text: 'By continuing, you agree to IrriKart’s ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                children: const [
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
