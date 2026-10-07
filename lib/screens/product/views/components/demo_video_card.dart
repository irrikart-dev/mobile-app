import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../components/ui/ui.dart';

/// "Watch the demo" card — hands off to YouTube (or whatever app owns the
/// URL) rather than embedding a player.
class DemoVideoCard extends StatelessWidget {
  const DemoVideoCard({super.key, required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnack.error(context, 'Could not open the video.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: () => _open(context),
      padding: const EdgeInsets.all(AppSpacing.smd),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.errorSoft,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(Icons.play_arrow_rounded, size: 32, color: c.error),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Watch the product demo', style: context.text.title),
                const SizedBox(height: 2),
                Text(
                  'See installation and use in the field',
                  style: context.text.captionMuted,
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded, size: 18, color: c.textMuted),
        ],
      ),
    );
  }
}
