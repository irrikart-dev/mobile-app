import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../models/address_data.dart';
import 'components/indian_state_picker.dart';

/// One screen for both add and edit — [existing] set means edit.
class AddEditAddressScreen extends ConsumerStatefulWidget {
  const AddEditAddressScreen({super.key, this.existing});

  final Address? existing;

  @override
  ConsumerState<AddEditAddressScreen> createState() =>
      _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends ConsumerState<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone =
      TextEditingController(text: _localPhone(widget.existing?.phone));
  late final _line1 = TextEditingController(text: widget.existing?.line1);
  late final _line2 = TextEditingController(text: widget.existing?.line2);
  late final _city = TextEditingController(text: widget.existing?.city);
  late final _state = TextEditingController(text: widget.existing?.state);
  late final _pincode = TextEditingController(text: widget.existing?.pincode);
  late bool _makeDefault = widget.existing?.isDefault ?? false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// Edits always show the bare 10-digit number; "+91" is implied.
  static String? _localPhone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits.length == 10 ? digits : raw;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Enter $what' : null;

  Future<void> _pickState() async {
    FocusScope.of(context).unfocus();
    final picked = await showIndianStatePicker(
      context,
      selected: _state.text.trim().isEmpty ? null : _state.text.trim(),
    );
    if (picked != null && mounted) {
      setState(() => _state.text = picked);
      _formKey.currentState?.validate();
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      AppSnack.show(
        context,
        'Please fix the highlighted fields',
        tone: Tone.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final notifier = ref.read(addressControllerProvider.notifier);
      if (_isEdit) {
        final existing = widget.existing!;
        await notifier.edit(
          existing.id,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          line1: _line1.text.trim(),
          line2: _line2.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          pincode: _pincode.text.trim(),
        );
        if (_makeDefault && !existing.isDefault) {
          await notifier.setDefault(existing.id);
        }
      } else {
        final before = {
          for (final a in ref.read(addressControllerProvider).valueOrNull ??
              const <Address>[])
            a.id,
        };
        await notifier.add(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          line1: _line1.text.trim(),
          line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          pincode: _pincode.text.trim(),
        );
        if (_makeDefault) {
          // `add` refreshes the list; the new row is the one we hadn't seen.
          final after = ref.read(addressControllerProvider).valueOrNull ??
              const <Address>[];
          final created = after.where((a) => !before.contains(a.id));
          if (created.length == 1 && !created.first.isDefault) {
            await notifier.setDefault(created.first.id);
          }
        }
      }
      if (!mounted) return;
      AppSnack.success(context, _isEdit ? 'Address updated' : 'Address saved');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnack.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const gap = SizedBox(height: AppSpacing.md);
    final alreadyDefault = widget.existing?.isDefault ?? false;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(title: _isEdit ? 'Edit address' : 'Add address'),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.smd,
              AppSpacing.gutter,
              AppSpacing.smd,
            ),
            child: AppButton(
              label: _isEdit ? 'Save changes' : 'Save address',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              SectionCard(
                title: 'Contact',
                icon: Icons.person_outline_rounded,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Full name',
                      controller: _name,
                      hint: 'Who will receive the delivery',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      maxLength: 60,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Enter the recipient’s name';
                        if (t.length < 2) return 'Name is too short';
                        return null;
                      },
                    ),
                    gap,
                    AppTextField(
                      label: 'Mobile number',
                      controller: _phone,
                      hint: '98765 43210',
                      helper: '+91 · used by the courier to reach you',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Enter a mobile number';
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(t)) {
                          return 'Enter a valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Delivery address',
                icon: Icons.location_on_rounded,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Pincode',
                      controller: _pincode,
                      hint: '6-digit pincode',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.postalCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Enter the pincode';
                        if (!RegExp(r'^[1-9]\d{5}$').hasMatch(t)) {
                          return 'Enter a valid 6-digit pincode';
                        }
                        return null;
                      },
                    ),
                    gap,
                    AppTextField(
                      label: 'Address line 1',
                      controller: _line1,
                      hint: 'House / farm no., village, street',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.streetAddressLine1],
                      maxLength: 120,
                      validator: (v) => _required(v, 'the address'),
                    ),
                    gap,
                    AppTextField(
                      label: 'Address line 2',
                      optional: true,
                      controller: _line2,
                      hint: 'Landmark, tehsil, post office',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.streetAddressLine2],
                      maxLength: 120,
                    ),
                    gap,
                    AppTextField(
                      label: 'City / District',
                      controller: _city,
                      hint: 'e.g. Nashik',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.addressCity],
                      maxLength: 60,
                      validator: (v) => _required(v, 'the city or district'),
                    ),
                    gap,
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickState,
                      child: AbsorbPointer(
                        child: AppTextField(
                          label: 'State',
                          controller: _state,
                          hint: 'Select state or UT',
                          prefixIcon: Icons.map_rounded,
                          suffix: Icon(
                            Icons.expand_more_rounded,
                            color: c.textMuted,
                          ),
                          validator: (v) => _required(v, 'the state'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile.adaptive(
                  value: _makeDefault,
                  onChanged: alreadyDefault
                      ? null
                      : (v) => setState(() => _makeDefault = v),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  title: Text('Set as default', style: context.text.bodyStrong),
                  subtitle: Text(
                    alreadyDefault
                        ? 'This is your default delivery address'
                        : 'Pre-selected at checkout',
                    style: context.text.caption,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
