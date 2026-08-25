import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class NotificationOptionsScreen extends StatelessWidget {
  const NotificationOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Notification options',
      icon: Icons.tune,
      title: 'Notification preferences',
      message:
          'Choose which order, delivery and offer alerts you want, per channel.',
    );
  }
}
