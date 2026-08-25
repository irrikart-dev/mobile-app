import 'package:flutter/material.dart';

import '../../../constants.dart';
import 'components/info_sheet.dart';

/// Return policy sheet.
///
/// Placeholder copy for the Indian market — the upstream template shipped a
/// US/Canada policy. Real per-product windows come from
/// `isReturnable` / `returnWindowDays` in the catalogue module.
class ProductReturnsScreen extends StatelessWidget {
  const ProductReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InfoSheet(
      title: 'Returns',
      children: [
        const SpecRow('Return window', '7 days from delivery'),
        const SpecRow('Pickup', 'Free reverse pickup where serviceable'),
        const SpecRow('Refund', 'To source, or IrriKart wallet'),
        const SizedBox(height: defaultPadding * 1.5),
        Text('What can be returned', style: theme.textTheme.titleSmall),
        const SizedBox(height: defaultPadding / 2),
        const Text(
          'Unused items in their original packaging, and any item that arrives '
          'damaged or not as described. Report damage within 48 hours of '
          'delivery with photographs.',
        ),
        const SizedBox(height: defaultPadding),
        Text('What cannot be returned', style: theme.textTheme.titleSmall),
        const SizedBox(height: defaultPadding / 2),
        const Text(
          'Opened seed, fertilizer and crop-protection packs cannot be '
          'returned once the seal is broken, for safety and traceability. '
          'Made-to-order items are also non-returnable.',
        ),
      ],
    );
  }
}
