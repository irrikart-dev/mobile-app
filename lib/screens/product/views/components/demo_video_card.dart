import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../components/ui/ui.dart';
import 'delivery_info_card.dart';

/// "Watch the demo" row — hands off to YouTube (or whatever app owns the
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
    return PdpIconRow(
      icon: Icons.play_arrow_rounded,
      title: 'Watch the product demo',
      subtitle: 'Installation and use in the field',
      trailingIcon: Icons.open_in_new_rounded,
      onTap: () => _open(context),
    );
  }
}
