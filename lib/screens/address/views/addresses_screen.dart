import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Addresses',
      icon: Icons.location_on_outlined,
      title: 'Saved addresses',
      message:
          'Save your farm and delivery addresses, and check which pincodes we '
          'serve, once delivery is wired up.',
    );
  }
}
