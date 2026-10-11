import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/auth_validators.dart';

/// What the email sheet hands back once the user is signed in.
class EmailAuthResult {
  const EmailAuthResult({this.newName});

  /// The name typed while creating an account, for the backend profile.
  /// Null for a plain sign-in.
  final String? newName;
}

enum EmailAuthMode { signIn, signUp, forgot, resetSent }

/// "Continue with email" — sign in, create an account, or reset a password,
/// all in one bottom sheet. Resolves to an [EmailAuthResult] once Firebase
/// has signed the user in, or null if they close it.
Future<EmailAuthResult?> showEmailAuthSheet(
  BuildContext context, {
  EmailAuthMode initialMode = EmailAuthMode.signIn,
}) {
  return showAppSheet<EmailAuthResult>(
    context,
    builder: (_) => EmailAuthForm(initialMode: initialMode),
  );
}

/// The sheet's body. Public so tests and the screenshot harness can pump it
/// directly.
class EmailAuthForm extends ConsumerStatefulWidget {
  const EmailAuthForm({super.key, this.initialMode = EmailAuthMode.signIn});

  final EmailAuthMode initialMode;

  @override
  ConsumerState<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends ConsumerState<EmailAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late EmailAuthMode _mode = widget.initialMode;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// The keyed column in [build] rebuilds every field for the new mode, so
  /// stale validation errors vanish while the typed email carries over.
  void _switchTo(EmailAuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _password.clear();
      _confirm.clear();
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authServiceProvider);
    try {
      switch (_mode) {
        case EmailAuthMode.signIn:
          await auth.signInWithEmail(_email.text, _password.text);
          if (mounted) Navigator.of(context).pop(const EmailAuthResult());
        case EmailAuthMode.signUp:
          final name = _name.text.trim();
          await auth.createAccountWithEmail(
            _email.text,
            _password.text,
            displayName: name.isEmpty ? null : name,
          );
          if (mounted) {
            Navigator.of(context).pop(
              EmailAuthResult(newName: name.isEmpty ? null : name),
            );
          }
        case EmailAuthMode.forgot:
          await auth.sendPasswordResetEmail(_email.text);
          if (mounted) setState(() => _mode = EmailAuthMode.resetSent);
        case EmailAuthMode.resetSent:
          break;
      }
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
    return AnimatedSize(
      duration: AppDurations.normal,
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              key: ValueKey(_mode),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: switch (_mode) {
                EmailAuthMode.signIn => _signIn(context),
                EmailAuthMode.signUp => _signUp(context),
                EmailAuthMode.forgot => _forgot(context),
                EmailAuthMode.resetSent => _resetSent(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _header(String title, String subtitle) => [
        Text(title, style: context.text.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: context.text.bodySecondary),
        const SizedBox(height: AppSpacing.lg),
      ];

  Widget _emailField({TextInputAction action = TextInputAction.next}) =>
      AppTextField(
        label: 'Email',
        controller: _email,
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        textInputAction: action,
        autofillHints: const [AutofillHints.email],
        validator: AuthValidators.emailError,
        enabled: !_busy,
        onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
      );

  Widget _visibilityToggle() => IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );

  Widget _errorBanner() => AnimatedSize(
        duration: AppDurations.fast,
        child: _error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: InlineBanner(message: _error!, tone: Tone.error),
              ),
      );

  Widget _switchLine(String prompt, String action, EmailAuthMode to) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(prompt, style: context.text.bodySecondary)),
          AppButton.ghost(
            label: action,
            size: AppButtonSize.sm,
            onPressed: _busy ? null : () => _switchTo(to),
          ),
        ],
      );

  List<Widget> _signIn(BuildContext context) => [
        ..._header(
          'Sign in with email',
          'Welcome back — enter the email and password for your account.',
        ),
        _emailField(),
        const SizedBox(height: AppSpacing.md),
        _PasswordField(
          controller: _password,
          label: 'Password',
          obscure: _obscure,
          toggle: _visibilityToggle(),
          validator: AuthValidators.passwordPresentError,
          autofill: AutofillHints.password,
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton.ghost(
            label: 'Forgot password?',
            size: AppButtonSize.sm,
            onPressed: _busy ? null : () => _switchTo(EmailAuthMode.forgot),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _errorBanner(),
        AppButton(label: 'Sign in', loading: _busy, onPressed: _submit),
        const SizedBox(height: AppSpacing.sm),
        _switchLine(
          'New to IrriKart?',
          'Create an account',
          EmailAuthMode.signUp,
        ),
      ];

  List<Widget> _signUp(BuildContext context) => [
        ..._header(
          'Create your account',
          'Use any email you check — we’ll send order updates there.',
        ),
        AppTextField(
          label: 'Full name',
          optional: true,
          controller: _name,
          hint: 'e.g. Ravi Kumar',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          maxLength: AuthValidators.maxNameLength,
          validator: (v) => AuthValidators.nameError(v, optional: true),
          enabled: !_busy,
        ),
        const SizedBox(height: AppSpacing.md),
        _emailField(),
        const SizedBox(height: AppSpacing.md),
        _PasswordField(
          controller: _password,
          label: 'Password',
          helper: 'At least ${AuthValidators.minPasswordLength} characters',
          obscure: _obscure,
          toggle: _visibilityToggle(),
          validator: AuthValidators.newPasswordError,
          autofill: AutofillHints.newPassword,
          action: TextInputAction.next,
          enabled: !_busy,
        ),
        const SizedBox(height: AppSpacing.md),
        _PasswordField(
          controller: _confirm,
          label: 'Confirm password',
          obscure: _obscure,
          validator: (v) =>
              AuthValidators.confirmPasswordError(v, _password.text),
          autofill: AutofillHints.newPassword,
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.lg),
        _errorBanner(),
        AppButton(
          label: 'Create account',
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        _switchLine(
          'Already have an account?',
          'Sign in',
          EmailAuthMode.signIn,
        ),
      ];

  List<Widget> _forgot(BuildContext context) => [
        ..._header(
          'Reset your password',
          'Enter your account email and we’ll send you a link to choose a '
              'new password.',
        ),
        _emailField(action: TextInputAction.done),
        const SizedBox(height: AppSpacing.lg),
        _errorBanner(),
        AppButton(
          label: 'Send reset link',
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: AppButton.ghost(
            label: 'Back to sign in',
            icon: Icons.arrow_back_rounded,
            size: AppButtonSize.sm,
            onPressed: _busy ? null : () => _switchTo(EmailAuthMode.signIn),
          ),
        ),
      ];

  List<Widget> _resetSent(BuildContext context) {
    final c = context.colors;
    return [
      const SizedBox(height: AppSpacing.sm),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.successSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 30,
            color: c.success,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Check your inbox',
        textAlign: TextAlign.center,
        style: context.text.h2,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text.rich(
        TextSpan(
          text: 'If an account exists for ',
          children: [
            TextSpan(
              text: _email.text.trim(),
              style: context.text.bodyStrong,
            ),
            const TextSpan(
              text: ', you’ll get a link to reset your password in a few '
                  'minutes. Check spam too.',
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: context.text.bodySecondary,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        label: 'Back to sign in',
        onPressed: () => _switchTo(EmailAuthMode.signIn),
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.validator,
    required this.autofill,
    this.toggle,
    this.helper,
    this.action = TextInputAction.done,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final FormFieldValidator<String> validator;
  final String autofill;
  final Widget? toggle;
  final String? helper;
  final TextInputAction action;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // AppTextField has no `obscureText`, so this mirrors its layout: label
    // above, themed input below.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.text.label),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          enableSuggestions: false,
          autocorrect: false,
          validator: validator,
          textInputAction: action,
          autofillHints: [autofill],
          onFieldSubmitted: onSubmitted,
          style: context.text.body,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: '••••••••',
            helperText: helper,
            suffixIcon: toggle,
          ),
        ),
      ],
    );
  }
}
