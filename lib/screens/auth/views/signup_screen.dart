import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/auth/signup_api.dart';
import 'package:irrikart/route/route_constants.dart';

import '../../../constants.dart';
import 'components/auth_unavailable_notice.dart';
import 'components/google_sign_in_button.dart';

enum _SignupStep { email, otp, password }

/// Sign-up in three steps: email -> emailed OTP -> set password.
///
/// The account is only created on the backend once the OTP is verified (see
/// [SignupApi]), so nothing exists in Firebase for an email nobody actually
/// checked. The final step signs this device in with the custom token the
/// backend hands back.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  _SignupStep _step = _SignupStep.email;

  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  String? _signupToken;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  Timer? _cooldownTimer;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown -= 1);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _requestOtp() async {
    if (_busy) return;
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(signupApiProvider).requestOtp(_email.text.trim());
      if (!mounted) return;
      _startCooldown();
      setState(() => _step = _SignupStep.otp);
    } on SignupApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Skips the email/OTP/password steps entirely — Google has already
  /// verified the address, and Firebase creates the account on first sign-in.
  Future<void> _continueWithGoogle() async {
    if (_googleBusy) return;
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted || credential == null) return; // null = picker was closed
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
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(signupApiProvider)
          .verifyOtp(_email.text.trim(), _otp.text.trim());
      if (!mounted) return;
      setState(() {
        _signupToken = token;
        _step = _SignupStep.password;
      });
    } on SignupApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeSignup() async {
    if (_busy) return;
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    final token = _signupToken;
    if (token == null) {
      setState(() {
        _error = 'Your verification expired. Please start again.';
        _step = _SignupStep.email;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final customToken = await ref
          .read(signupApiProvider)
          .completeSignup(token, _newPassword.text);
      await ref.read(authServiceProvider).signInWithCustomToken(customToken);
      if (!mounted) return;
      unawaited(
        Navigator.pushNamedAndRemoveUntil(
          context,
          entryPointScreenRoute,
          (route) => false,
        ),
      );
    } on SignupApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } on AuthUnavailableException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Steps back one stage instead of leaving the screen, so the back button
  /// never silently drops progress the user has already made.
  void _goBack() {
    setState(() {
      _error = null;
      _step = switch (_step) {
        _SignupStep.email => _SignupStep.email,
        _SignupStep.otp => _SignupStep.email,
        _SignupStep.password => _SignupStep.otp,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final authAvailable = ref.watch(authServiceProvider).isAvailable;

    return PopScope(
      canPop: _step == _SignupStep.email,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: _step == _SignupStep.email
            ? null
            : AppBar(
                title: Text(
                  switch (_step) {
                    _SignupStep.otp => 'Verify your email',
                    _SignupStep.password => 'Set a password',
                    _SignupStep.email => '',
                  },
                ),
              ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (_step == _SignupStep.email)
                Image.asset(
                  'assets/images/signUp_dark.png',
                  height: MediaQuery.of(context).size.height * 0.35,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!authAvailable) ...[
                      const AuthUnavailableNotice(),
                      const SizedBox(height: defaultPadding),
                    ],
                    switch (_step) {
                      _SignupStep.email => _emailStep(authAvailable),
                      _SignupStep.otp => _otpStep(authAvailable),
                      _SignupStep.password => _passwordStep(authAvailable),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailStep(bool authAvailable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Let’s get started!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: defaultPadding / 2),
        const Text('Enter your email — we’ll send you a code to verify it.'),
        const SizedBox(height: defaultPadding),
        Form(
          key: _emailFormKey,
          child: TextFormField(
            controller: _email,
            enabled: authAvailable && !_busy,
            validator: emaildValidator.call,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _requestOtp(),
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
                child: Icon(Icons.mail_outline),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: defaultPadding / 2),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: defaultPadding * 1.5),
        ElevatedButton(
          onPressed: authAvailable && !_busy ? _requestOtp : null,
          child: _busy ? const _ButtonSpinner() : const Text('Send code'),
        ),
        const SizedBox(height: defaultPadding),
        const OrDivider(),
        const SizedBox(height: defaultPadding),
        GoogleSignInButton(
          busy: _googleBusy,
          onPressed: authAvailable ? _continueWithGoogle : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Do you have an account?'),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, logInScreenRoute),
              child: const Text('Log in'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _otpStep(bool authAvailable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter the code',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: defaultPadding / 2),
        Text('We sent a 6-digit code to ${_email.text.trim()}.'),
        const SizedBox(height: defaultPadding),
        Form(
          key: _otpFormKey,
          child: TextFormField(
            controller: _otp,
            enabled: authAvailable && !_busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            onFieldSubmitted: (_) => _verifyOtp(),
            style: const TextStyle(fontSize: 22, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: '',
              hintText: '000000',
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.length != 6 || int.tryParse(v) == null) {
                return 'Enter the 6-digit code';
              }
              return null;
            },
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: defaultPadding / 2),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: defaultPadding * 1.5),
        ElevatedButton(
          onPressed: authAvailable && !_busy ? _verifyOtp : null,
          child: _busy ? const _ButtonSpinner() : const Text('Verify'),
        ),
        Align(
          child: TextButton(
            onPressed: (authAvailable && !_busy && _resendCooldown == 0)
                ? _requestOtp
                : null,
            child: Text(
              _resendCooldown > 0
                  ? 'Resend code in ${_resendCooldown}s'
                  : 'Resend code',
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep(bool authAvailable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set a password',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: defaultPadding / 2),
        const Text('One last step — choose a password for your account.'),
        const SizedBox(height: defaultPadding),
        Form(
          key: _passwordFormKey,
          child: Column(
            children: [
              _PasswordField(
                controller: _newPassword,
                hintText: 'New password',
                enabled: authAvailable && !_busy,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = value ?? '';
                  if (v.length < 8) return 'At least 8 characters';
                  if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Add a letter';
                  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
                  return null;
                },
              ),
              const SizedBox(height: defaultPadding),
              _PasswordField(
                controller: _confirmPassword,
                hintText: 'Confirm password',
                enabled: authAvailable && !_busy,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _completeSignup(),
                validator: (value) =>
                    value != _newPassword.text ? pasNotMatchErrorText : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: defaultPadding / 2),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: defaultPadding * 1.5),
        ElevatedButton(
          onPressed: authAvailable && !_busy ? _completeSignup : null,
          child: _busy ? const _ButtonSpinner() : const Text('Create account'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final String? Function(String?) validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(
      context,
    ).textTheme.bodyLarge!.color!.withValues(alpha: 0.3);
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
          child: Icon(Icons.lock_outline),
        ),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: hintColor,
          ),
          tooltip: _obscure ? 'Show password' : 'Hide password',
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
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
        horizontal: defaultPadding * 0.75,
        vertical: defaultPadding * 0.6,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(defaultBorderRadious),
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
