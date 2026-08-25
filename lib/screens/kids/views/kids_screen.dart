import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

/// Placeholder for a generic category landing page.
///
/// Inherited from the apparel template as "Kids"; it becomes
/// CategoryLandingScreen in the catalog module.
class KidsScreen extends StatelessWidget {
  const KidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Category',
      icon: Icons.grid_view_outlined,
      title: 'Browse by category',
      message: 'Category listings with filters and sorting arrive with the '
          'catalogue module.',
    );
  }
}
