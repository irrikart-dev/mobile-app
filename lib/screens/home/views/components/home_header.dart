import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../models/notification_data.dart';
import '../../../../models/wishlist_state.dart';
import '../../../../route/route_constants.dart';

/// Home's greeting row: "Hello, {first name}" + prompt, then the
/// notification bell (signed in) and the wishlist shortcut, with live counts.
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
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
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
                  style: context.text.h1,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'What does your farm need today?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary,
                ),
              ],
            ),
          ),
          if (user != null) ...[
            const SizedBox(width: AppSpacing.smd),
            AppIconButton(
              size: 48,
              icon: unread > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              filled: true,
              badgeCount: unread,
              onPressed: () =>
                  Navigator.pushNamed(context, notificationsScreenRoute),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
            size: 48,
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
