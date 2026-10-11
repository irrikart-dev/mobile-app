import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_validators.dart';
import '../../../core/auth/profile_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/tokens/color_tokens.dart';
import '../../../route/route_constants.dart';
import 'components/auth_hero.dart';
import 'components/auth_method_button.dart';
import 'components/auth_unavailable_notice.dart';
import 'components/email_auth_sheet.dart';
import 'components/google_sign_in_button.dart';
import 'components/otp_code_field.dart';
import 'components/phone_number_field.dart';
import 'components/terms_consent.dart';

/// The app's single entry point into an account: mobile number + OTP as the
/// main path, with Google and email + password as alternatives.
///
/// Serves both `logInScreenRoute` and `signUpScreenRoute` — every method
/// creates the account on first use and just authenticates it after. Nothing
/// unlocks until the Terms & Conditions box is ticked.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _Step { methods, otp }

/// Which request is in flight, so only its button spins.
enum _Pending { none, phone, google, verify, resend }

class _AuthScreenState extends ConsumerState<AuthScreen>
    with WidgetsBindingObserver {
  static const _resendCooldown = 30;
  static const _codeLength = 6;

  final _phoneFormKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otp = TextEditingController();
  final _termsKey = GlobalKey();
  final _continueKey = GlobalKey();

  /// Validate the number live only after the first "Continue" — no red
  /// error while someone is still typing their first digits.
  bool _phoneSubmitted = false;

  late bool _termsAccepted =
      ref.read(localStoreProvider).termsAcceptedAt != null;
  int _termsAttention = 0;

  _Step _step = _Step.methods;
  _Pending _pending = _Pending.none;
  String? _error;
  bool _signedIn = false;

  String? _phoneE164;
  String? _verificationId;
  int? _resendToken;
  int _resendIn = 0;
  Timer? _resendTimer;
  StreamSubscription<PhoneAuthEvent>? _phoneSub;

  /// Android read the SMS itself and the automatic sign-in is running.
  bool _autoVerifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// When the keyboard opens over the phone field, scroll far enough that
  /// the "Continue" button clears it too, not just the caret.
  @override
  void didChangeMetrics() {
    if (!_phoneFocus.hasFocus || _step != _Step.methods) return;
    unawaited(Future<void>.delayed(AppDurations.normal, _revealContinue));
  }

  void _revealContinue() {
    final target = _continueKey.currentContext;
    if (target == null || !target.mounted || !_phoneFocus.hasFocus) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneSub?.cancel();
    _resendTimer?.cancel();
    _phone.dispose();
    _phoneFocus.dispose();
    _otp.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Terms gate
  // ---------------------------------------------------------------------

  void _setTermsAccepted(bool accepted) {
    setState(() => _termsAccepted = accepted);
    unawaited(
      ref
          .read(localStoreProvider)
          .setTermsAcceptedAt(accepted ? DateTime.now() : null),
    );
  }

  /// True if the user may proceed; otherwise draws attention to the
  /// checkbox (shake + hint, scrolled into view) and returns false.
  bool _requireTerms() {
    if (_termsAccepted) return true;
    setState(() => _termsAttention++);
    unawaited(HapticFeedback.mediumImpact());
    final box = _termsKey.currentContext;
    if (box != null) {
      unawaited(
        Scrollable.ensureVisible(
          box,
          duration: AppDurations.normal,
          curve: AppCurves.standard,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // After any successful sign-in
  // ---------------------------------------------------------------------

  /// Shared tail of every sign-in method. [newName] is a name typed while
  /// creating an email account, copied to the backend profile once the
  /// account row exists.
  Future<void> _onSignedIn({String? newName}) async {
    if (_signedIn || !mounted) return;
    _signedIn = true;
    unawaited(_phoneSub?.cancel());
    _resendTimer?.cancel();

    final store = ref.read(localStoreProvider);
    // Signed-in users never see onboarding again, even after a later log-out.
    unawaited(store.markOnboardingCompleted());
    if (store.termsAcceptedAt == null) {
      unawaited(store.setTermsAcceptedAt(DateTime.now()));
    }

    unawaited(
      _syncAccount(
        ref.read(dioProvider),
        ref.read(profileApiProvider),
        newName,
      ),
    );

    unawaited(
      Navigator.pushNamedAndRemoveUntil(
        context,
        entryPointScreenRoute,
        (route) => false,
      ),
    );
  }

  /// Mirrors the Firebase account into the backend's own User table —
  /// cart/orders 401 with "No account linked" until this has run once.
  /// Best-effort: the Dio interceptor retries the sync itself on the next
  /// authenticated call if it doesn't land here for any reason.
  static Future<void> _syncAccount(
    Dio dio,
    ProfileApi profile,
    String? newName,
  ) async {
    try {
      await dio.post<dynamic>('/auth/firebase/sync');
      if (newName != null) await profile.updateName(newName);
    } catch (e) {
      debugPrint('Post-sign-in account sync failed: $e');
    }
  }

  void _fail(String message) {
    if (mounted && !_signedIn) setState(() => _error = message);
  }

  // ---------------------------------------------------------------------
  // Phone + OTP
  // ---------------------------------------------------------------------

  Future<void> _sendCode({bool resend = false}) async {
    if (_pending != _Pending.none || _signedIn) return;
    if (!_requireTerms()) return;
    if (!resend) {
      if (!_phoneSubmitted) setState(() => _phoneSubmitted = true);
      final valid = _phoneFormKey.currentState?.validate() ?? false;
      final digits = AuthValidators.indianMobileDigits(_phone.text);
      if (!valid || digits == null) return;
      _phoneE164 = AuthValidators.toE164(digits);
      FocusScope.of(context).unfocus();
    }
    final phone = _phoneE164;
    if (phone == null) return;

    setState(() {
      _pending = resend ? _Pending.resend : _Pending.phone;
      _error = null;
    });
    await _phoneSub?.cancel();
    try {
      _phoneSub = ref
          .read(authServiceProvider)
          .verifyPhoneNumber(phone, resendToken: resend ? _resendToken : null)
          .listen(_onPhoneEvent);
    } on AuthUnavailableException catch (e) {
      setState(() => _pending = _Pending.none);
      _fail(e.userMessage);
    }
  }

  void _onPhoneEvent(PhoneAuthEvent event) {
    if (!mounted || _signedIn) return;
    switch (event) {
      case OtpSent(:final verificationId, :final resendToken):
        final wasResend = _pending == _Pending.resend;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _pending = _Pending.none;
          _error = null;
          _step = _Step.otp;
        });
        _otp.clear();
        _startResendCountdown();
        if (wasResend) AppSnack.success(context, 'A new code is on its way');
      case OtpAutoFilled(:final smsCode):
        _otp.text = smsCode;
        setState(() {
          _autoVerifying = true;
          _error = null;
          _step = _Step.otp;
        });
      case OtpAutoSignedIn():
        unawaited(_onSignedIn());
      case OtpFailed(:final error):
        setState(() {
          _pending = _Pending.none;
          _autoVerifying = false;
        });
        _fail(error.userMessage);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verifyCode([String? typed]) async {
    final code = typed ?? _otp.text;
    final verificationId = _verificationId;
    if (_pending != _Pending.none || _signedIn || verificationId == null) {
      return;
    }
    if (code.length != _codeLength) {
      _fail('Enter the $_codeLength-digit code from the SMS.');
      return;
    }
    setState(() {
      _pending = _Pending.verify;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .confirmSmsCode(verificationId: verificationId, smsCode: code);
      await _onSignedIn();
    } on AuthException catch (e) {
      // Android may have signed in automatically meanwhile — that wins.
      if (_signedIn || !mounted) return;
      if (e.code == 'invalid-verification-code') _otp.clear();
      _fail(e.userMessage);
    } on AuthUnavailableException catch (e) {
      _fail(e.userMessage);
    } finally {
      if (mounted && !_signedIn) setState(() => _pending = _Pending.none);
    }
  }

  void _changeNumber() {
    unawaited(_phoneSub?.cancel());
    _phoneSub = null;
    _resendTimer?.cancel();
    _otp.clear();
    setState(() {
      _step = _Step.methods;
      _pending = _Pending.none;
      _autoVerifying = false;
      _verificationId = null;
      _error = null;
    });
    _phoneFocus.requestFocus();
  }

  // ---------------------------------------------------------------------
  // Google, email
  // ---------------------------------------------------------------------

  Future<void> _continueWithGoogle() async {
    if (_pending != _Pending.none || _signedIn) return;
    if (!_requireTerms()) return;
    setState(() {
      _pending = _Pending.google;
      _error = null;
    });
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (credential != null) await _onSignedIn(); // null = picker closed
    } on AuthException catch (e) {
      _fail(e.userMessage);
    } on AuthUnavailableException catch (e) {
      _fail(e.userMessage);
    } finally {
      if (mounted && !_signedIn) setState(() => _pending = _Pending.none);
    }
  }

  Future<void> _continueWithEmail() async {
    if (_pending != _Pending.none || _signedIn) return;
    if (!_requireTerms()) return;
    setState(() => _error = null);
    final result = await showEmailAuthSheet(context);
    if (result != null) await _onSignedIn(newName: result.newName);
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authAvailable = ref.watch(authServiceProvider).isAvailable;
    final c = context.colors;

    return PopScope(
      canPop: _step == _Step.methods,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _changeNumber();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          // Matches the hero gradient's last stop, so the sheet's rounded
          // corners sit on the same green.
          backgroundColor: AppColors.forestDark,
          body: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: AuthHero()),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: AppRadius.sheetTop,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg + AppSpacing.xs,
                    AppSpacing.lg,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDurations.normal,
                    switchInCurve: AppCurves.emphasized,
                    switchOutCurve: AppCurves.standard,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, if (current != null) current],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _step == _Step.methods
                        ? _methodsStep(context, authAvailable)
                        : _otpStep(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() => AnimatedSize(
        duration: AppDurations.fast,
        alignment: Alignment.topCenter,
        child: _error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: AppSpacing.smd),
                child: InlineBanner(message: _error!, tone: Tone.error),
              ),
      );

  Widget _methodsStep(BuildContext context, bool authAvailable) {
    final c = context.colors;
    final locked = authAvailable && !_termsAccepted;

    /// [action] while usable; null (disabled) while terms are unticked,
    /// auth is down, or a different method is mid-request.
    VoidCallback? gated(_Pending self, VoidCallback action) => authAvailable &&
            _termsAccepted &&
            (_pending == _Pending.none || _pending == self)
        ? action
        : null;

    return Column(
      key: const ValueKey(_Step.methods),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Welcome to IrriKart', style: context.text.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sign in or create an account in seconds.',
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.mdPlus),
        if (!authAvailable) ...[
          const AuthUnavailableNotice(),
          const SizedBox(height: AppSpacing.md),
        ],
        Form(
          key: _phoneFormKey,
          autovalidateMode: _phoneSubmitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: PhoneNumberField(
            controller: _phone,
            focusNode: _phoneFocus,
            enabled: _pending == _Pending.none,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _sendCode(),
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        _Gate(
          locked: locked,
          onLockedTap: _requireTerms,
          child: AppButton(
            key: _continueKey,
            label: 'Continue',
            trailingIcon: Icons.arrow_forward_rounded,
            loading: _pending == _Pending.phone,
            onPressed: gated(_Pending.phone, _sendCode),
          ),
        ),
        _errorBanner(),
        const SizedBox(height: AppSpacing.md),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.md),
        _Gate(
          locked: locked,
          onLockedTap: _requireTerms,
          child: GoogleSignInButton(
            busy: _pending == _Pending.google,
            onPressed: gated(_Pending.google, _continueWithGoogle),
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        _Gate(
          locked: locked,
          onLockedTap: _requireTerms,
          child: AuthMethodButton(
            leading: Icon(
              Icons.mail_outline_rounded,
              size: 20,
              color: c.textPrimary,
            ),
            label: 'Continue with email',
            onPressed: gated(_Pending.none, _continueWithEmail),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TermsConsent(
          key: _termsKey,
          accepted: _termsAccepted,
          attention: _termsAttention,
          onChanged: _setTermsAccepted,
        ),
      ],
    );
  }

  Widget _otpStep(BuildContext context) {
    final c = context.colors;
    final verifying = _pending == _Pending.verify || _autoVerifying;
    final codeError = _error != null && _otp.text.isEmpty;

    return Column(
      key: const ValueKey(_Step.otp),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Enter the code', style: context.text.h1),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            text: 'We’ve sent a $_codeLength-digit code by SMS to ',
            children: [
              TextSpan(
                // Non-breaking, so the number never wraps mid-way.
                text: AuthValidators.formatPhone(_phoneE164 ?? '')
                    .replaceAll(' ', ' '),
                style: context.text.bodyStrong,
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        OtpCodeField(
          controller: _otp,
          length: _codeLength,
          autofocus: !_autoVerifying,
          enabled: !verifying,
          hasError: codeError,
          onCompleted: _verifyCode,
        ),
        AnimatedSize(
          duration: AppDurations.fast,
          alignment: Alignment.topCenter,
          child: _autoVerifying
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.smd),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sms_outlined,
                        size: AppSpacing.md,
                        color: c.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Code detected automatically — signing you in…',
                          style: context.text.caption,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        _errorBanner(),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Verify and continue',
          loading: verifying,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: AppSpacing.smd),
        _ResendRow(
          secondsLeft: _resendIn,
          sending: _pending == _Pending.resend,
          onResend: verifying || _pending != _Pending.none
              ? null
              : () => _sendCode(resend: true),
        ),
        Center(
          child: AppButton.ghost(
            label: 'Change number',
            size: AppButtonSize.sm,
            onPressed: verifying ? null : _changeNumber,
          ),
        ),
      ],
    );
  }
}

/// Lets a disabled method still react to taps — by pointing at the Terms
/// checkbox — while [locked]. Unlocked it's transparent to gestures.
class _Gate extends StatelessWidget {
  const _Gate({
    required this.locked,
    required this.onLockedTap,
    required this.child,
  });

  final bool locked;
  final VoidCallback onLockedTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: locked ? onLockedTap : null,
      child: child,
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: c.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or', style: context.text.captionMuted),
        ),
        Expanded(child: Divider(color: c.divider, height: 1)),
      ],
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.sending,
    required this.onResend,
  });

  final int secondsLeft;
  final bool sending;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      final s = secondsLeft.toString().padLeft(2, '0');
      return SizedBox(
        height: AppButtonSize.sm.height,
        child: Center(
          child: Text.rich(
            TextSpan(
              text: 'Didn’t get it? Resend in ',
              children: [
                TextSpan(
                  text: '0:$s',
                  style: context.text.caption.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            style: context.text.caption,
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Didn’t get it?', style: context.text.caption),
        AppButton.ghost(
          label: 'Resend code',
          size: AppButtonSize.sm,
          loading: sending,
          onPressed: onResend,
        ),
      ],
    );
  }
}
