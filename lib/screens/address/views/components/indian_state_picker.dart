import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// All 28 states and 8 union territories of India, alphabetical.
const indianStatesAndUts = <String>[
  'Andaman and Nicobar Islands',
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chandigarh',
  'Chhattisgarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jammu and Kashmir',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Ladakh',
  'Lakshadweep',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Puducherry',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
];

/// Opens a searchable sheet of [indianStatesAndUts]; resolves to the chosen
/// name, or null if dismissed.
Future<String?> showIndianStatePicker(
  BuildContext context, {
  String? selected,
}) {
  return showAppSheet<String>(
    context,
    title: 'Select state',
    scrollable: false,
    padding: EdgeInsets.zero,
    builder: (_) => _StatePickerBody(selected: selected),
  );
}

class _StatePickerBody extends StatefulWidget {
  const _StatePickerBody({this.selected});

  final String? selected;

  @override
  State<_StatePickerBody> createState() => _StatePickerBodyState();
}

class _StatePickerBodyState extends State<_StatePickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? indianStatesAndUts
        : indianStatesAndUts.where((s) => s.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.sm,
          ),
          child: AppSearchField(
            hint: 'Search states and UTs',
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No match',
                  message: 'Check the spelling and try again.',
                  compact: true,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final name = items[i];
                    final isSelected = name == widget.selected;
                    return InkWell(
                      onTap: () => Navigator.pop(context, name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter,
                          vertical: AppSpacing.smd + 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: isSelected
                                    ? context.text.bodyStrong
                                        .copyWith(color: c.primary)
                                    : context.text.body,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: c.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
