import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/config/support_config.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../entry_point_tab.dart';
import '../../../models/address_data.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';
import 'account_providers.dart';
import 'components/account_avatar.dart';

/// Account tab root: who you are, shortcuts to orders/wishlist/addresses,
/// settings, support and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(accountUserProvider).valueOrNull ??
        ref.watch(authStateProvider).valueOrNull;
    final signedIn = user != null;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const AppTopBar(title: 'Account', large: true, showBack: false),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.fabClearance + context.bottomInset,
        ),
        children: [
          if (signedIn) _ProfileHeader(user: user) else const _SignInPrompt(),
          const SizedBox(height: AppSpacing.md),
          _QuickActions(signedIn: signedIn),
          const SizedBox(height: AppSpacing.sectionGap),
          if (signedIn) ...[
            SettingsGroup(
              title: 'Account',
              children: [
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Your details',
                  subtitle: 'Name and sign-in info',
                  onTap: () => Navigator.pushNamed(context, userInfoScreenRoute),
                ),
                SettingsTile(
                  icon: Icons.location_on_rounded,
                  title: 'Saved addresses',
                  subtitle: 'Delivery locations for your orders',
                  onTap: () =>
                      Navigator.pushNamed(context, addressesScreenRoute),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SettingsGroup(
            title: 'Preferences',
            children: [
              SettingsTile(
                icon: Icons.palette_rounded,
                title: 'Appearance',
                subtitle: _themeLabel(themeMode),
                onTap: () =>
                    Navigator.pushNamed(context, preferencesScreenRoute),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsGroup(
            title: 'Support',
            children: [
              SettingsTile(
                icon: Icons.chat_rounded,
                title: 'Chat on WhatsApp',
                subtitle: 'Product advice, orders, bulk enquiries',
                onTap: () => openWhatsAppSupport(
                  context,
                  message: 'Hi IrriKart team, I need some help.',
                ),
              ),
              SettingsTile(
                icon: Icons.assignment_return_rounded,
                title: 'Returns & refunds',
                subtitle: 'How returns work on IrriKart',
                onTap: () =>
                    Navigator.pushNamed(context, productReturnsScreenRoute),
              ),
              SettingsTile(
                icon: Icons.description_rounded,
                title: 'Terms of Service',
                trailing: _externalIcon(context),
                showChevron: false,
                onTap: () => _openUrl(context, SupportConfig.termsUrl),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                trailing: _externalIcon(context),
                showChevron: false,
                onTap: () => _openUrl(context, SupportConfig.privacyUrl),
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.lg),
            SettingsGroup(
              title: 'Developer',
              children: [
                SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset onboarding',
                  subtitle: 'Shows the intro screens on next launch',
                  onTap: () async {
                    await ref.read(localStoreProvider).resetOnboarding();
                    if (context.mounted) {
                      AppSnack.success(context, 'Onboarding reset');
                    }
                  },
                ),
                if (signedIn) const _CopyIdTokenTile(),
              ],
            ),
          ],
          if (signedIn) ...[
            const SizedBox(height: AppSpacing.lg),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  destructive: true,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _VersionFooter(),
        ],
      ),
    );
  }
}

String _themeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Match system',
    };

Widget _externalIcon(BuildContext context) => Icon(
      Icons.open_in_new_rounded,
      size: 18,
      color: context.colors.textMuted,
    );

Future<void> _openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    AppSnack.error(context, 'Could not open the page. Please try again.');
  }
}

/// Signs out after confirmation, then returns to the login screen.
Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Log out?',
    message: 'You will need to log in again to place orders and see your '
        'order history.',
    confirmLabel: 'Log out',
    destructive: true,
    icon: Icons.logout_rounded,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(authServiceProvider).signOut();
  } catch (e) {
    if (context.mounted) AppSnack.error(context, friendlyError(e));
    return;
  }
  if (!context.mounted) return;
  unawaited(
    Navigator.pushNamedAndRemoveUntil(context, logInScreenRoute, (_) => false),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final name = accountDisplayName(user);
    final email = user.email;

    return AppCard(
      onTap: () => Navigator.pushNamed(context, userInfoScreenRoute),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AccountAvatar(name: name, photoUrl: user.photoURL, size: 60),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.title,
                ),
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                const StatusPill(
                  label: 'Verified account',
                  tone: Tone.success,
                  icon: Icons.verified_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton.ghost(
            label: 'Edit',
            size: AppButtonSize.sm,
            onPressed: () => Navigator.pushNamed(context, userInfoScreenRoute),
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      color: c.primarySoft,
      borderColor: c.primarySoft,
      padding: const EdgeInsets.all(AppSpacing.mdPlus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: Icon(Icons.person_rounded, color: c.primary),
          ),
          const SizedBox(height: AppSpacing.smd),
          Text(
            'Sign in to IrriKart',
            style: context.text.h3.copyWith(color: c.onPrimarySoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Track orders, save delivery addresses and keep your wishlist '
            'in sync across devices.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Sign in',
            icon: Icons.login_rounded,
            size: AppButtonSize.md,
            onPressed: () => Navigator.pushNamed(context, logInScreenRoute),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistCount = ref.watch(
      wishlistControllerProvider.select((s) => s.length),
    );
    final addressCount = signedIn
        ? ref.watch(addressControllerProvider).valueOrNull?.length
        : null;

    void requireSignIn(VoidCallback action) {
      if (signedIn) {
        action();
      } else {
        Navigator.pushNamed(context, logInScreenRoute);
      }
    }

    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            caption: 'Track & reorder',
            onTap: () => requireSignIn(
              () => ref.read(entryTabIndexProvider.notifier).state = 3,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.smd),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.favorite_rounded,
            label: 'Wishlist',
            caption: wishlistCount == 1 ? '1 item' : '$wishlistCount items',
            onTap: () => Navigator.pushNamed(context, bookmarkScreenRoute),
          ),
        ),
        const SizedBox(width: AppSpacing.smd),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.location_on_rounded,
            label: 'Addresses',
            caption: addressCount == null
                ? 'Manage'
                : addressCount == 1
                    ? '1 saved'
                    : '$addressCount saved',
            onTap: () => requireSignIn(
              () => Navigator.pushNamed(context, addressesScreenRoute),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, size: 22, color: c.onPrimarySoft),
            ),
            const SizedBox(height: AppSpacing.smd),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSm,
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.captionMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionFooter extends ConsumerWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    return Column(
      children: [
        Icon(Icons.water_drop_rounded, size: 20, color: context.colors.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          version == null ? 'IrriKart' : 'IrriKart v$version',
          textAlign: TextAlign.center,
          style: context.text.captionMuted,
        ),
        const SizedBox(height: 2),
        Text(
          'Made for Indian farmers',
          textAlign: TextAlign.center,
          style: context.text.captionMuted,
        ),
      ],
    );
  }
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
      if (mounted) AppSnack.success(context, 'ID token copied to clipboard');
    } catch (e) {
      if (mounted) AppSnack.error(context, 'Could not get token: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.key_rounded,
      title: 'Copy ID token',
      subtitle: 'For testing the API with curl',
      onTap: _busy ? null : _copy,
      trailing: _busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
