import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "Continue with Google" — the app's only sign-in method. New and returning
/// accounts go through the same call ([AuthService.signInWithGoogle]).
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
    final theme = Theme.of(context);
    final disabled = busy || onPressed == null;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: disabled ? 0 : 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: disabled ? null : onPressed,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                )
              else ...[
                SvgPicture.string(_googleLogoSvg, height: 20, width: 20),
                const SizedBox(width: 14),
                Text(
                  'Continue with Google',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Google's official multi-colour "G" mark, from Google's own Identity
/// branding assets. Embedded inline rather than as a bundled asset file —
/// one small, unchanging vector with no reason to round-trip the asset
/// bundle for it.
const _googleLogoSvg = '''
<svg width="18" height="18" xmlns="http://www.w3.org/2000/svg">
  <g fill="none" fill-rule="evenodd">
    <path d="M17.64 9.2045c0-.6381-.0573-1.2518-.1636-1.8409H9v3.4814h4.8436c-.2086 1.125-.8427 2.0782-1.7959 2.7164v2.2581h2.9087c1.7018-1.5668 2.6836-3.8741 2.6836-6.615z" fill="#4285F4"/>
    <path d="M9 18c2.43 0 4.4673-.806 5.9564-2.1805l-2.9087-2.2581c-.8059.54-1.8368.859-3.0477.859-2.344 0-4.3282-1.5831-5.036-3.7104H.9573v2.3318C2.4382 15.9832 5.4818 18 9 18z" fill="#34A853"/>
    <path d="M3.964 10.71c-.18-.54-.2822-1.1168-.2822-1.71s.1023-1.17.2823-1.71V4.9582H.9573C.3477 6.1732 0 7.5477 0 9s.3477 2.8268.9573 4.0418L3.964 10.71z" fill="#FBBC05"/>
    <path d="M9 3.5795c1.3214 0 2.5077.4541 3.4405 1.346l2.5813-2.5814C13.4632.891 11.4259 0 9 0 5.4818 0 2.4382 2.0168.9573 4.9582L3.964 7.29C4.6718 5.1627 6.656 3.5795 9 3.5795z" fill="#EA4335"/>
  </g>
</svg>
''';
