import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/auth/auth_validators.dart';

/// Indian mobile number input: a fixed 🇮🇳 +91 prefix and the 10 national
/// digits. Styled by the app's input theme, with the label above the field
/// exactly like `AppTextField`.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Mobile number', style: context.text.label),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: const [IndianMobileInputFormatter()],
          // Validated by the enclosing Form, which decides when.
          validator: AuthValidators.phoneError,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          style: context.text.body.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
          decoration: InputDecoration(
            hintText: '10-digit number',
            counterText: '',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.smd,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.xsAll / 2,
                    child: SvgPicture.asset(
                      'assets/flags/India.svg',
                      width: 22,
                      height: 16,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '+91',
                    style: context.text.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  SizedBox(
                    height: 22,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: c.borderStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
