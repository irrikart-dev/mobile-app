import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../constants.dart';

class LogInForm extends StatefulWidget {
  const LogInForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    this.onSubmitted,
    this.enabled = true,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  /// Fired by the keyboard's "done" action, so the form can be submitted
  /// without reaching for the button.
  final VoidCallback? onSubmitted;

  final bool enabled;

  @override
  State<LogInForm> createState() => _LogInFormState();
}

class _LogInFormState extends State<LogInForm> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final hintColor =
        Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.3);

    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          TextFormField(
            controller: widget.emailController,
            enabled: widget.enabled,
            validator: emaildValidator.call,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              hintText: 'Email address',
              prefixIcon: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
                child: SvgPicture.asset(
                  'assets/icons/Message.svg',
                  height: 24,
                  width: 24,
                  colorFilter: ColorFilter.mode(hintColor, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding),
          TextFormField(
            controller: widget.passwordController,
            enabled: widget.enabled,
            // Login only checks the field is filled: an old account may predate
            // the current complexity rules, and rejecting it here would lock
            // the user out of a password that still works.
            validator: (value) => (value == null || value.isEmpty)
                ? 'Password is required'
                : null,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => widget.onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
                child: SvgPicture.asset(
                  'assets/icons/Lock.svg',
                  height: 24,
                  width: 24,
                  colorFilter: ColorFilter.mode(hintColor, BlendMode.srcIn),
                ),
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
          ),
        ],
      ),
    );
  }
}
