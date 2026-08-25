import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

/// Was the apparel size guide; becomes the product specification guide
/// (capacity, motor rating, material, coverage) in the catalog module.
class SizeGuideScreen extends StatelessWidget {
  const SizeGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Specifications',
      icon: Icons.straighten,
      title: 'Specification guide',
      message:
          'Full technical specifications - capacity, motor rating, material '
          'and coverage - will be listed here.',
    );
  }
}
