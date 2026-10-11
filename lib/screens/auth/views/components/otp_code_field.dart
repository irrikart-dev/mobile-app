import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../components/ui/ui.dart';

/// Six one-digit boxes backed by a single invisible text field, so typing,
/// backspace, paste and the OS one-time-code autofill (iOS) all behave like
/// one input. Android's SMS auto-retrieval fills [controller] directly.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final focused = _focus.hasFocus && widget.enabled;
    final active = code.length.clamp(0, widget.length - 1);

    return Semantics(
      label: 'One-time code, ${widget.length} digits',
      textField: true,
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _DigitBox(
                      digit: i < code.length ? code[i] : null,
                      active: focused && i == active,
                      error: widget.hasError,
                    ),
                  ),
                ],
              ],
            ),
            // The real input: full-size so a tap anywhere focuses it, but
            // never painted.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: const InputDecoration.collapsed(hintText: null),
                  onChanged: (v) {
                    if (v.length == widget.length) widget.onCompleted?.call(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.digit,
    required this.active,
    required this.error,
  });

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final borderColor = error
        ? c.error
        : active
            ? c.primary
            : digit != null
                ? c.borderStrong
                : c.surfaceSunken;

    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: borderColor, width: active ? 1.6 : 1),
      ),
      alignment: Alignment.center,
      child: digit != null
          ? Text(digit!, style: context.text.h2)
          : active
              ? Container(width: 2, height: 22, color: c.primary)
              : null,
    );
  }
}
