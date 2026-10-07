import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../route/route_constants.dart';
import '../../profile/views/account_providers.dart';
import '../../profile/views/components/account_avatar.dart';

/// "Your details": edit display name; email and sign-in method are shown
/// read-only because Google owns them.
class UserInfoScreen extends ConsumerWidget {
  const UserInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);
    final user = userAsync.valueOrNull ?? ref.watch(authStateProvider).valueOrNull;

    final Widget body;
    if (user != null) {
      body = _DetailsForm(user: user);
    } else if (userAsync.isLoading) {
      body = const _DetailsSkeleton();
    } else if (userAsync.hasError) {
      body = ErrorState(
        error: userAsync.error,
        onRetry: () => ref.invalidate(accountUserProvider),
      );
    } else {
      body = EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'You’re not signed in',
        message: 'Sign in to view and edit your details.',
        actionLabel: 'Sign in',
        onAction: () => Navigator.pushNamed(context, logInScreenRoute),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const AppTopBar(title: 'Your details'),
      body: body,
    );
  }
}

class _DetailsForm extends StatefulWidget {
  const _DetailsForm({required this.user});

  final User user;

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.user.displayName?.trim() ?? '');
  late final _email = TextEditingController(text: widget.user.email ?? '');
  bool _saving = false;
  late String _savedName = _name.text;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  bool get _dirty => _name.text.trim() != _savedName;

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name';
    if (v.length < 2) return 'Name must be at least 2 characters';
    if (v.length > 40) return 'Name must be 40 characters or fewer';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) throw StateError('Signed out');
      await current.updateDisplayName(name);
      await current.reload();
      if (!mounted) return;
      setState(() => _savedName = name);
      AppSnack.success(context, 'Your name has been updated');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnack.error(
          context,
          e.code == 'network-request-failed'
              ? 'You appear to be offline. Check your connection and try again.'
              : 'Could not update your name. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'Could not update your name. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = widget.user;
    final displayName =
        _name.text.trim().isEmpty ? accountDisplayName(user) : _name.text.trim();
    final isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              children: [
                Center(
                  child: AccountAvatar(
                    name: displayName,
                    photoUrl: user.photoURL,
                    size: 96,
                    ring: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.smd),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.h2,
                ),
                if (user.photoURL != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Profile photo comes from your Google account',
                    textAlign: TextAlign.center,
                    style: context.text.captionMuted,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  title: 'Profile',
                  icon: Icons.person_outline_rounded,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Display name',
                        controller: _name,
                        hint: 'e.g. Ravi Kumar',
                        helper: 'Shown on your orders and invoices',
                        validator: _validateName,
                        maxLength: 40,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.name],
                        prefixIcon: Icons.badge_rounded,
                        onSubmitted: (_) => _dirty && !_saving ? _save() : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        enabled: false,
                        prefixIcon: Icons.mail_outline_rounded,
                        helper: isGoogle ? 'Managed by Google' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsGroup(
                  title: 'Sign-in method',
                  children: [
                    SettingsTile(
                      icon: isGoogle
                          ? Icons.g_mobiledata_rounded
                          : Icons.alternate_email_rounded,
                      title: isGoogle ? 'Google' : 'Email & password',
                      subtitle: user.email,
                      showChevron: false,
                      trailing: const StatusPill(
                        label: 'Connected',
                        tone: Tone.success,
                        dot: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _StickyFooter(
          child: AppButton(
            label: 'Save changes',
            loading: _saving,
            onPressed: _dirty && !_saving ? _save : null,
          ),
        ),
        // Keeps the footer flush with the system nav bar.
        ColoredBox(
          color: c.surface,
          child: SizedBox(height: context.bottomInset),
        ),
      ],
    );
  }
}

class _StickyFooter extends StatelessWidget {
  const _StickyFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.smd,
        AppSpacing.gutter,
        AppSpacing.smd,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: child,
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: const [
        Center(
          child: ShimmerBox(
            height: 96,
            width: 96,
            borderRadius: AppRadius.pillAll,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Center(child: ShimmerBox(height: 20, width: 160)),
        SizedBox(height: AppSpacing.lg),
        ShimmerBox(height: 180, borderRadius: AppRadius.mdAll),
        SizedBox(height: AppSpacing.md),
        ShimmerBox(height: 64, borderRadius: AppRadius.mdAll),
      ],
    );
  }
}
