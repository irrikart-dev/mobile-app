import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/screen_export.dart';
import 'components/profile_card.dart';
import 'components/profile_menu_item_list_tile.dart';

/// Account tab. Matches the reference theme's `account-screen`: profile
/// summary, orders/wishlist/addresses, preferences, help, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistCount = ref.watch(
      wishlistControllerProvider.select((s) => s.length),
    );
    final user = ref.watch(authStateProvider).valueOrNull;
    final signedIn = user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          ProfileCard(
            name: user?.displayName?.trim().isNotEmpty == true
                ? user!.displayName!
                : 'Farmer',
            email: user?.email ?? 'Log in to sync your orders and wishlist',
            imageSrc: user?.photoURL ?? 'https://i.imgur.com/IXnwbLk.png',
            press: () => Navigator.pushNamed(
              context,
              signedIn ? userInfoScreenRoute : logInScreenRoute,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SectionLabel('Orders & Wishlist'),
          ProfileMenuListTile(
            text: 'My Orders',
            svgSrc: 'assets/icons/Order.svg',
            press: () => Navigator.pushNamed(context, ordersScreenRoute),
          ),
          ProfileMenuListTile(
            text: wishlistCount > 0 ? 'Wishlist ($wishlistCount)' : 'Wishlist',
            svgSrc: 'assets/icons/Wishlist.svg',
            press: () => Navigator.pushNamed(context, bookmarkScreenRoute),
          ),
          ProfileMenuListTile(
            text: 'Saved Addresses',
            svgSrc: 'assets/icons/Address.svg',
            press: () => Navigator.pushNamed(context, addressesScreenRoute),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SectionLabel('Preferences'),
          ProfileMenuListTile(
            text: 'Notifications',
            svgSrc: 'assets/icons/Notification.svg',
            press: () => Navigator.pushNamed(context, notificationsScreenRoute),
          ),
          ProfileMenuListTile(
            text: 'App Preferences',
            svgSrc: 'assets/icons/Preferences.svg',
            press: () => Navigator.pushNamed(context, preferencesScreenRoute),
            isShowDivider: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SectionLabel('Help & Support'),
          ProfileMenuListTile(
            text: 'Get Help',
            svgSrc: 'assets/icons/Help.svg',
            press: () {},
            isShowDivider: signedIn && kDebugMode,
          ),
          if (signedIn && kDebugMode) const _CopyIdTokenTile(),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            onTap: () => signedIn
                ? _confirmSignOut(context, ref)
                : Navigator.pushNamed(context, logInScreenRoute),
            minLeadingWidth: 24,
            leading: SvgPicture.asset(
              'assets/icons/Logout.svg',
              height: 24,
              width: 24,
              colorFilter: ColorFilter.mode(
                signedIn
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
            title: Text(
              signedIn ? 'Log Out' : 'Log In',
              style: TextStyle(
                color: signedIn
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                fontSize: 14,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Signs out after confirmation, then returns to the login screen.
Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to log in again to place orders.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await ref.read(authServiceProvider).signOut();
  if (!context.mounted) return;
  unawaited(
    Navigator.pushNamedAndRemoveUntil(context, logInScreenRoute, (_) => false),
  );
}

/// Debug-only: copies the raw Firebase ID token so it can be tested against
/// the backend directly (`curl -H "Authorization: Bearer <token>" ...`) —
/// the fastest way to tell apart a client bug from the backend verifying
/// against the wrong Firebase project. Never shown in a release build.
class _CopyIdTokenTile extends ConsumerStatefulWidget {
  const _CopyIdTokenTile();

  @override
  ConsumerState<_CopyIdTokenTile> createState() => _CopyIdTokenTileState();
}

class _CopyIdTokenTileState extends ConsumerState<_CopyIdTokenTile> {
  bool _busy = false;

  Future<void> _copy() async {
    setState(() => _busy = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = await user?.getIdToken(true);
      if (token == null) throw StateError('No signed-in user');
      await Clipboard.setData(ClipboardData(text: token));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID token copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get token: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: _busy ? null : _copy,
      minLeadingWidth: 24,
      leading: Icon(
        Icons.bug_report_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text(
        'Copy ID token (debug)',
        style: TextStyle(fontSize: 14, height: 1),
      ),
      trailing: _busy
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
