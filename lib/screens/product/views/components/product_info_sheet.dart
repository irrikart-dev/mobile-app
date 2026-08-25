import 'package:flutter/material.dart';

import '../../../../constants.dart';
import 'info_sheet.dart';

/// Product specification sheet.
///
/// Values are placeholders until the catalogue module supplies real
/// SpecAttribute data from the API.
class ProductInfoSheet extends StatelessWidget {
  const ProductInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InfoSheet(
      title: 'Product details',
      children: [
        Text('Description', style: theme.textTheme.titleSmall),
        const SizedBox(height: defaultPadding / 2),
        const Text(
          'Built for daily field use, with parts that are easy to source and '
          'replace locally.',
        ),
        const SizedBox(height: defaultPadding * 1.5),
        Text('Specifications', style: theme.textTheme.titleSmall),
        const SizedBox(height: defaultPadding / 2),
        const SpecRow('Capacity', '16 L'),
        const SpecRow('Material', 'HDPE tank'),
        const SpecRow('Pump type', 'Manual lever'),
        const SpecRow('Nozzles included', '4'),
        const SpecRow('Weight', '4.2 kg'),
        const SpecRow('Warranty', '1 year manufacturer warranty'),
        const SpecRow('Country of origin', 'India'),
      ],
    );
  }
}
