import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';

/// Labelled form field. The label sits above the input (not floating inside
/// it) — easier to scan on long forms like the address editor.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.enabled = true,
    this.optional = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool optional;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (optional)
                TextSpan(
                  text: '  Optional',
                  style: context.text.caption.copyWith(color: c.textMuted),
                ),
            ],
          ),
          style: context.text.label,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          style: context.text.body,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            counterText: '',
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Search input. With [onTap] set and [readOnly] true it acts as a tappable
/// entry point into the search screen (Home, Categories); otherwise it's the
/// live field on the search screen itself.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Search pumps, drip kits, tools…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.readOnly = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: c.border),
    );
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        autofocus: autofocus,
        onTap: onTap,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: context.text.body,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          fillColor: c.surface,
          prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 22),
          suffixIcon: onClear == null || controller == null
              ? null
              : ListenableBuilder(
                  listenable: controller!,
                  builder: (context, _) => controller!.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: c.textMuted,
                              ),
                              onPressed: onClear,
                            )
                          : const SizedBox.shrink(),
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: c.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}
