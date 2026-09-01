import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/route/route_constants.dart';
import 'package:irrikart/screens/auth/views/components/auth_unavailable_notice.dart';
import 'package:irrikart/screens/auth/views/components/sign_up_form.dart';

import '../../../constants.dart';

/// Account creation with Firebase email/password. A verification email is sent
/// on success, but the catalogue is browsable before it is confirmed.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _acceptedTerms = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      setState(
          () => _error = 'Please accept the terms of service to continue.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signUp(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created. We sent a verification link to ${_email.text.trim()}.',
          ),
        ),
      );
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                  Text(
                    'Let’s get started!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  const Text(
                    'Create your IrriKart account to order, track and reorder.',
                  ),
                  const SizedBox(height: defaultPadding),
                  if (!authAvailable) ...[
                    const AuthUnavailableNotice(),
                    const SizedBox(height: defaultPadding),
                  ],
                  SignUpForm(
                    formKey: _formKey,
                    nameController: _name,
                    emailController: _email,
                    passwordController: _password,
                    enabled: authAvailable && !_busy,
                    onSubmitted: _submit,
                  ),
                  const SizedBox(height: defaultPadding),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _acceptedTerms = value ?? false),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree with the',
                            children: [
                              TextSpan(
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.pushNamed(
                                      context,
                                      termsOfServicesScreenRoute,
                                    );
                                  },
                                text: ' Terms of service ',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const TextSpan(text: '& privacy policy.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: defaultPadding / 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding * 0.75,
                        vertical: defaultPadding * 0.6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius:
                            BorderRadius.circular(defaultBorderRadious),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: scheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: defaultPadding * 2),
                  ElevatedButton(
                    onPressed: authAvailable && !_busy ? _submit : null,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Do you have an account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, logInScreenRoute);
                        },
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
