import 'package:flutter/material.dart';

import '../../../../components/catalog_image.dart';
import '../../../../components/ui/ui.dart';
import '../account_providers.dart';

/// Circular user avatar: the Google profile photo when there is one, else
/// the user's initials on the soft brand tint. Never a stock placeholder.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 64,
    this.ring = false,
  });

  final String name;
  final String? photoUrl;
  final double size;

  /// Draws a surface-coloured ring + soft border around the avatar, for the
  /// large hero avatar on "Your details".
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final url = photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    final inner = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: hasPhoto
            ? CatalogImage(source: url, isRemote: true)
            : ColoredBox(
                color: c.primarySoft,
                child: Center(
                  child: Text(
                    accountInitials(name),
                    style: (size >= 80 ? context.text.h1 : context.text.h3)
                        .copyWith(color: c.onPrimarySoft),
                  ),
                ),
              ),
      ),
    );

    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface,
        border: Border.all(color: c.border),
      ),
      child: inner,
    );
  }
}
