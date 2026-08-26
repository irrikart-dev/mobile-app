import 'package:flutter/material.dart';

import '../core/theme/tokens/typography_tokens.dart';

/// The small script-font eyebrow label above a section heading — e.g.
/// "Fresh picks" over "Popular this week". A recurring motif in the
/// reference design: `.kicker` styled with the script font at every section
/// head.
class AppKicker extends StatelessWidget {
  const AppKicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.kicker(
        color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
