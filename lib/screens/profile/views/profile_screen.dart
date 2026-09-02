import 'dart:async';

import 'package:flutter/material.dart';
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
          if (signedIn && !user.emailVerified) const _VerifyEmailBanner(),
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
            isShowDivider: false,
          ),
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

/// Nudge to confirm the address Firebase mailed a verification link to.
class _VerifyEmailBanner extends ConsumerStatefulWidget {
  const _VerifyEmailBanner();

  @override
  ConsumerState<_VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends ConsumerState<_VerifyEmailBanner> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Verify your email to secure your account.',
              style:
                  TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _sending ? null : _resend,
            child: Text(_sending ? 'Sending…' : 'Resend'),
          ),
        ],
      ),
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
