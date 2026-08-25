import 'package:flutter/material.dart';

import '../../../../constants.dart';
import 'info_sheet.dart';

/// Shipping information sheet.
///
/// The pincode serviceability check becomes live in the shipping module;
/// until then the field is present but inert.
class ShippingInfoSheet extends StatelessWidget {
  const ShippingInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InfoSheet(
      title: 'Shipping information',
      children: [
        Text('Delivery', style: theme.textTheme.titleSmall),
        const SizedBox(height: defaultPadding / 2),
        const SpecRow('Dispatch', 'Within 2 business days'),
        const SpecRow('Delivery', '3-7 business days'),
        const SpecRow('Shipping', 'Free above ₹999'),
        const SpecRow('Cash on delivery', 'Available on eligible pincodes'),
        const SizedBox(height: defaultPadding * 1.5),
        Text('Check your pincode', style: theme.textTheme.titleSmall),
        const SizedBox(height: defaultPadding / 2),
        const TextField(
          enabled: false,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter 6-digit pincode',
            helperText: 'Serviceability check is coming soon.',
          ),
        ),
      ],
    );
  }
}
