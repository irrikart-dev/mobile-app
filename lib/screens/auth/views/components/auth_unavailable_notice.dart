import 'package:flutter/material.dart';

import '../../../../constants.dart';

/// Shown on the auth screens when Firebase is not configured or failed to
/// initialise. The catalogue still works, so this explains the missing
/// capability rather than blocking the whole screen.
class AuthUnavailableNotice extends StatelessWidget {
  const AuthUnavailableNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(defaultPadding * 0.75),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(defaultBorderRadious),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign-in is not available yet',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'This build has no Firebase configuration. Browsing the '
                  'catalogue works as normal.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
