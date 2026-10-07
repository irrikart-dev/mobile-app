import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/theme_mode_controller.dart';

/// "Appearance": Light / Dark / System as three side-by-side preview tiles,
/// each a miniature of the app rendered in that theme's own palette.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  static const _options = [
    (
      mode: ThemeMode.light,
      title: 'Light',
      subtitle: 'Bright and clear — easiest to read outdoors in sunlight.',
    ),
    (
      mode: ThemeMode.dark,
      title: 'Dark',
      subtitle: 'Easier on the eyes at night, and saves battery.',
    ),
    (
      mode: ThemeMode.system,
      title: 'System',
      subtitle: 'Follows your phone’s display setting automatically.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final c = context.colors;
    final selected = _options.firstWhere(
      (o) => o.mode == current,
      orElse: () => _options.last,
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Appearance'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl + context.bottomInset,
        ),
        children: [
          Text('Choose a theme', style: context.text.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick how IrriKart looks on this device.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: _ThemeOption(
                    mode: _options[i].mode,
                    title: _options[i].title,
                    selected: current == _options[i].mode,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(_options[i].mode),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            child: Text(
              selected.subtitle,
              key: ValueKey(selected.mode),
              textAlign: TextAlign.center,
              style: context.text.bodySecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Saved on this phone and applied instantly.',
                  style: context.text.captionMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One selectable preview tile. Unselected tiles are borderless sage; the
/// selected one gets a 2px forest outline and a check badge.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title theme',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.tint,
                borderRadius: AppRadius.lgAll,
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                border:
                    selected ? Border.all(color: c.primary, width: 2) : null,
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 0.56,
                    child: ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: _ThemePreview(mode: mode),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs + AppSpacing.xxs,
                    right: AppSpacing.xs + AppSpacing.xxs,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: AppDurations.fast,
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: c.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.smd),
            Text(
              title,
              style: context.text.title.copyWith(
                color: selected ? c.primary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature phone screen drawn from blocks in the target theme's own
/// palette. "System" is split diagonally: light on the left, dark on the
/// right.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      ThemeMode.light => const _MiniScreen(palette: AppColorsExt.light),
      ThemeMode.dark => const _MiniScreen(palette: AppColorsExt.dark),
      ThemeMode.system => const Stack(
          fit: StackFit.expand,
          children: [
            _MiniScreen(palette: AppColorsExt.light),
            ClipPath(
              clipper: _DiagonalClipper(),
              child: _MiniScreen(palette: AppColorsExt.dark),
            ),
          ],
        ),
    };
  }
}

class _MiniScreen extends StatelessWidget {
  const _MiniScreen({required this.palette});

  final AppColorsExt palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget bar(double w, Color color, {double h = 4}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.pillAll,
          ),
        );

    Widget tile() => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.tint,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              bar(24, p.textSecondary, h: 3),
              const SizedBox(height: AppSpacing.xxs + 1),
              bar(14, p.textPrimary),
            ],
          ),
        );

    return ColoredBox(
      color: p.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.smd,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                bar(30, p.textPrimary, h: 6),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: p.tint,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: AppRadius.pillAll,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 34,
              padding: const EdgeInsets.all(AppSpacing.xs + 1),
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(28, p.textOnPrimary),
                  const SizedBox(height: AppSpacing.xxs + 1),
                  bar(18, p.accent),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Row(
                children: [
                  tile(),
                  const SizedBox(width: AppSpacing.xs + 1),
                  tile(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: p.navBar,
                borderRadius: AppRadius.pillAll,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? p.accent
                            : p.onNavBar.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
