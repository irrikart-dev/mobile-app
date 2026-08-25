import 'package:flutter/material.dart';

import '../constants.dart';

/// Honest placeholder for a screen that is routed but not built yet.
///
/// This replaces the upstream template's paywall widget, which rendered
/// screenshots of screens the free edition did not ship. Those screens were
/// never functional; this makes that explicit instead of implying otherwise.
///
/// Delete each usage as the real screen lands in its scheduled week.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.construction_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.64);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: primaryColor),
            ),
            const SizedBox(height: defaultPadding * 1.5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: defaultPadding / 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: defaultPadding * 1.5),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen variant with its own [Scaffold] and back button, for screens
/// pushed onto the navigator rather than hosted inside the tab shell.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.appBarTitle,
    required this.title,
    required this.message,
    this.icon = Icons.construction_outlined,
  });

  final String appBarTitle;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: ComingSoonView(title: title, message: message, icon: icon),
    );
  }
}
