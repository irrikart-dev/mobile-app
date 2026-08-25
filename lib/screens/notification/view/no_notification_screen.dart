import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class NoNotificationScreen extends StatelessWidget {
  const NoNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Notifications',
      icon: Icons.notifications_off_outlined,
      title: 'Nothing here yet',
      message: 'You have no notifications right now.',
    );
  }
}
