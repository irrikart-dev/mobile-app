import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../models/wishlist_state.dart';
import '../../../../route/route_constants.dart';

/// Home's greeting row: "Hello, {first name}" + prompt, and the wishlist
/// shortcut with a live count.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  static String _firstName(String? displayName) {
    final name = displayName?.trim() ?? '';
    if (name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(authStateProvider).valueOrNull;
    final firstName = _firstName(user?.displayName);
    final wishlistCount = ref.watch(wishlistControllerProvider).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.smd,
        AppSpacing.smd,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  firstName.isEmpty ? 'Hello there' : 'Hello, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.h2,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'What does your farm need today?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary.copyWith(
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
            icon: wishlistCount > 0
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: wishlistCount > 0 ? c.wishlist : null,
            tooltip: 'Wishlist',
            filled: true,
            badgeCount: wishlistCount,
            onPressed: () => Navigator.pushNamed(context, bookmarkScreenRoute),
          ),
        ],
      ),
    );
  }
}
