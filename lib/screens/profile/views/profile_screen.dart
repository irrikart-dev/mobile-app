import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          ProfileCard(
            name: 'Farmer',
            email: 'Add your phone number and email',
            imageSrc: 'https://i.imgur.com/IXnwbLk.png',
            press: () => Navigator.pushNamed(context, userInfoScreenRoute),
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
            isShowDivider: false,
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            onTap: () {},
            minLeadingWidth: 24,
            leading: SvgPicture.asset(
              'assets/icons/Logout.svg',
              height: 24,
              width: 24,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.error,
                BlendMode.srcIn,
              ),
            ),
            title: Text(
              'Log Out',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
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
