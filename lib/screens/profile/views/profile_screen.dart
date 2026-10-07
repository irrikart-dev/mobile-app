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
import '../../../models/order_data.dart';
import '../../../models/wishlist_state.dart';
import '../../../route/route_constants.dart';
import 'account_providers.dart';
import 'components/account_avatar.dart';

/// Account tab root: who you are, shortcuts to orders/wishlist/addresses,
/// settings, support and sign-out — all sitting directly on the canvas.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(accountUserProvider).valueOrNull ??
        ref.watch(authStateProvider).valueOrNull;
    final signedIn = user != null;
    final themeMode = ref.watch(themeModeProvider);
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Account', large: true, showBack: false),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.fabClearance + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (signedIn) _ProfileHeader(user: user) else const _SignInPrompt(),
          const SizedBox(height: AppSpacing.lg),
          _QuickActions(signedIn: signedIn),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Settings',
            children: [
              if (signedIn) ...[
                SettingsTile(
                  icon: Icons.person_rounded,
                  title: 'Your details',
                  onTap: () =>
                      Navigator.pushNamed(context, userInfoScreenRoute),
                ),
                SettingsTile(
                  icon: Icons.location_on_rounded,
                  title: 'Saved addresses',
                  onTap: () =>
                      Navigator.pushNamed(context, addressesScreenRoute),
                ),
              ],
              SettingsTile(
                icon: Icons.palette_rounded,
                title: 'Appearance',
                trailing: _TrailingValue(_themeLabel(themeMode)),
                onTap: () =>
                    Navigator.pushNamed(context, preferencesScreenRoute),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsGroup(
            title: 'Help & legal',
            children: [
              SettingsTile(
                icon: Icons.chat_bubble_rounded,
                title: 'Chat on WhatsApp',
                onTap: () => openWhatsAppSupport(
                  context,
                  message: 'Hi IrriKart team, I need some help.',
                ),
              ),
              SettingsTile(
                icon: Icons.assignment_return_rounded,
                title: 'Returns & refunds',
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
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: c.divider),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              destructive: true,
              onTap: () => _confirmSignOut(context, ref),
            ),
            SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: 'Delete account',
              subtitle: 'Permanently erase your account and data',
              destructive: true,
              onTap: () => _confirmDeleteAccount(context, ref),
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
      ThemeMode.system => 'System',
    };

Widget _externalIcon(BuildContext context) => Icon(
      Icons.north_east_rounded,
      size: 18,
      color: context.colors.textMuted,
    );

/// Muted current-value label shown before a row's chevron ("Light").
class _TrailingValue extends StatelessWidget {
  const _TrailingValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Text(
        value,
        style: context.text.body.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}

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

/// Account deletion (Play policy requires it in-app). Two steps: a clear
/// explanation of what is erased vs. kept, then a blocking progress dialog
/// while the server deletes everything.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete your account?',
    message: 'This permanently erases your profile, saved addresses, cart, '
        'wishlist and reviews. Past orders are kept without your name for '
        'GST records. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
    icon: Icons.delete_forever_rounded,
  );
  if (!confirmed || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );

  try {
    await deleteAccount(ref);
  } catch (e) {
    navigator.pop();
    if (context.mounted) AppSnack.error(context, friendlyError(e));
    return;
  }
  navigator.pop();
  unawaited(navigator.pushNamedAndRemoveUntil(logInScreenRoute, (_) => false));
  messenger.showSnackBar(
    const SnackBar(content: Text('Your account has been deleted.')),
  );
}

/// Avatar, name and email straight on the canvas — no card.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final name = accountDisplayName(user);
    final email = user.email;

    return Row(
      children: [
        AccountAvatar(name: name, photoUrl: user.photoURL, size: 72),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.h2,
              ),
              if (email != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.smd),
              _SmallPill(
                label: 'Edit profile',
                onTap: () => Navigator.pushNamed(context, userInfoScreenRoute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact tonal pill for low-weight header actions.
class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.primarySoft,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd + AppSpacing.xxs,
            vertical: AppSpacing.sm - AppSpacing.xxs,
          ),
          child: Text(
            label,
            style: context.text.label.copyWith(color: c.onPrimarySoft),
          ),
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, size: 32, color: c.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome to IrriKart', style: context.text.h2),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Sign in to track orders, save delivery addresses and '
                    'sync your wishlist.',
                    style: context.text.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.mdPlus),
        AppButton(
          label: 'Sign in',
          size: AppButtonSize.md,
          onPressed: () => Navigator.pushNamed(context, logInScreenRoute),
        ),
      ],
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
        : 0;
    final orderCount = signedIn
        ? ref.watch(orderHistoryProvider).valueOrNull?.length
        : 0;

    void requireSignIn(VoidCallback action) {
      if (signedIn) {
        action();
      } else {
        Navigator.pushNamed(context, logInScreenRoute);
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickActionTile(
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
              count: orderCount,
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
              count: wishlistCount,
              onTap: () => Navigator.pushNamed(context, bookmarkScreenRoute),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.location_on_rounded,
              label: 'Addresses',
              count: addressCount,
              onTap: () => requireSignIn(
                () => Navigator.pushNamed(context, addressesScreenRoute),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sage shortcut tile: icon disc, big count, label. The only tinted blocks
/// on the Account screen.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null while still loading.
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = count;
    return Semantics(
      button: true,
      label: n == null ? label : '$label, $n',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.smd + AppSpacing.xxs,
            AppSpacing.smd + AppSpacing.xxs,
            AppSpacing.smd,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: c.tint,
            borderRadius: AppRadius.lgAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: c.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                n == null ? '–' : '$n',
                style: context.text.h1.copyWith(
                  color: n == null ? c.textMuted : null,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.caption,
              ),
            ],
          ),
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
    return Text(
      '${version == null ? 'IrriKart' : 'IrriKart v$version'}'
      '  ·  Made for Indian farmers',
      textAlign: TextAlign.center,
      style: context.text.captionMuted,
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
