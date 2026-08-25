import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const ComingSoonView(
        icon: Icons.notifications_none,
        title: 'Notifications',
        message:
            'Order updates, dispatch and delivery alerts, quote replies and '
            'offers will arrive here.',
      ),
    );
  }
}
