import 'package:flutter/material.dart';

import '../../../../constants.dart';

/// "Continue with Google" — used on both the login and sign-up screens.
/// Firebase treats new and returning Google accounts identically, so one
/// button and one call ([AuthService.signInWithGoogle]) cover both.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.busy,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: defaultPadding * 0.7),
      ),
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleBadge(),
                const SizedBox(width: 10),
                Text(
                  'Continue with Google',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
    );
  }
}

/// "── or ──" separating the password form from Google sign-in.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: defaultPadding * 0.75),
          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

/// A plain "G" badge in Google's brand blue — avoids bundling a logo asset
/// or icon package for one glyph, without the fragility of hand-drawn arcs.
class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18,
      width: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFF4285F4), width: 1.5),
          ),
        ),
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4285F4),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
