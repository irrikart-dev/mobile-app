import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/constants.dart';
import 'package:irrikart/core/auth/auth_service.dart';

import 'components/auth_unavailable_notice.dart';

/// Sends a Firebase password-reset email.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: _sent ? _sentView(theme) : _formView(theme, authAvailable),
      ),
    );
  }

  Widget _formView(ThemeData theme, bool authAvailable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset your password', style: theme.textTheme.headlineSmall),
        const SizedBox(height: defaultPadding / 2),
        const Text(
          'Enter the email you registered with. We will send you a link to '
          'set a new password.',
        ),
        const SizedBox(height: defaultPadding),
        if (!authAvailable) ...[
          const AuthUnavailableNotice(),
          const SizedBox(height: defaultPadding),
        ],
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _email,
            enabled: authAvailable && !_busy,
            validator: emaildValidator.call,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
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
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: defaultPadding * 1.5),
        ElevatedButton(
          onPressed: authAvailable && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset link'),
        ),
      ],
    );
  }

  Widget _sentView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: defaultPadding),
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: defaultPadding),
        Text('Check your inbox', style: theme.textTheme.headlineSmall),
        const SizedBox(height: defaultPadding / 2),
        Text(
          'If an account exists for ${_email.text.trim()}, a reset link is on '
          'its way. It can take a couple of minutes to arrive — remember to '
          'check your spam folder.',
        ),
        const SizedBox(height: defaultPadding * 1.5),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to log in'),
        ),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
