import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class EnableNotificationScreen extends StatelessWidget {
  const EnableNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Notifications',
      icon: Icons.notifications_active_outlined,
      title: 'Turn on notifications',
      message:
          'Push notifications for order and delivery updates are set up in a '
          'later milestone.',
    );
  }
}
