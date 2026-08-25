import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class UserInfoScreen extends StatelessWidget {
  const UserInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Profile',
      icon: Icons.person_outline,
      title: 'Your details',
      message:
          'Editing your name, phone, farm details and GSTIN arrives with the '
          'account module.',
    );
  }
}
