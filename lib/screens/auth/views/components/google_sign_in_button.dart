import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../components/ui/ui.dart';

/// "Continue with Google" — the app's only sign-in method. Follows Google's
/// branding guidance: neutral surface, the multi-colour G, dark label.
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
    final c = context.colors;
    final disabled = busy || onPressed == null;

    return PressableScale(
      onTap: disabled ? null : onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.5 : 1,
        duration: AppDurations.fast,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.borderStrong),
            boxShadow: disabled ? null : c.shadowCard,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: c.textMuted,
                  ),
                )
              else ...[
                SvgPicture.string(_googleLogoSvg, height: 20, width: 20),
                const SizedBox(width: AppSpacing.smd),
                Text('Continue with Google', style: context.text.button),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Google's official multi-colour "G" mark, from Google's Identity branding
/// assets.
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
