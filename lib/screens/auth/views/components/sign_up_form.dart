import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../constants.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    this.onSubmitted,
    this.enabled = true,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
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
            controller: widget.nameController,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (value) => (value == null || value.trim().length < 2)
                ? 'Please enter your name'
                : null,
            decoration: InputDecoration(
              hintText: 'Full name',
              prefixIcon: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
                child: Icon(Icons.person_outline, size: 24, color: hintColor),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding),
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
            validator: passwordValidator.call,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => widget.onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: 'Password',
              helperText: 'At least 8 characters, with one special character',
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
