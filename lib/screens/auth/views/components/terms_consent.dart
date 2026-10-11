import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/config/support_config.dart';

/// "I agree to the Terms & Conditions and Privacy Policy" — mandatory before
/// any sign-in method unlocks.
///
/// Bump [attention] each time the user taps a method while this is
/// unticked: the row shakes once, its box turns red and a hint appears
/// underneath until it's ticked.
class TermsConsent extends StatefulWidget {
  const TermsConsent({
    super.key,
    required this.accepted,
    required this.onChanged,
    this.attention = 0,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final int attention;

  @override
  State<TermsConsent> createState() => _TermsConsentState();
}

class _TermsConsentState extends State<TermsConsent>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open(SupportConfig.termsUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(SupportConfig.privacyUrl);

  @override
  void didUpdateWidget(TermsConsent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attention != oldWidget.attention && !widget.accepted) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false);
    if (!ok && mounted) {
      AppSnack.error(context, 'Couldn’t open the page. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flagged = widget.attention > 0 && !widget.accepted;
    final linkStyle = context.text.caption.copyWith(
      color: c.primary,
      fontWeight: FontWeight.w700,
      fontSize: context.text.label.fontSize,
    );

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Three damped wiggles — enough to draw the eye, not a tantrum.
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppCurves.standard,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.smd,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: flagged ? c.errorSoft : c.background.withValues(alpha: 0),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: widget.accepted,
                  onChanged: (v) => widget.onChanged(v ?? false),
                  isError: flagged,
                  side: flagged ? BorderSide(color: c.error, width: 1.8) : null,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  semanticLabel: 'I agree to the Terms & Conditions and '
                      'Privacy Policy',
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChanged(!widget.accepted),
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: linkStyle,
                            recognizer: _terms,
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: linkStyle,
                            recognizer: _privacy,
                          ),
                        ],
                      ),
                      style: context.text.body.copyWith(
                        color: c.textSecondary,
                        fontSize: context.text.label.fontSize,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppDurations.fast,
            alignment: Alignment.topCenter,
            child: flagged
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      top: AppSpacing.xs,
                    ),
                    child: Text(
                      'Please accept to continue',
                      style: context.text.caption.copyWith(color: c.error),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
