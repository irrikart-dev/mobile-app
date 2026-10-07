import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../core/theme/theme_mode_controller.dart';

/// "Appearance": Light / Dark / Match system, each as a card with a small
/// rendered preview of the app in that theme.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  static const _options = [
    (
      mode: ThemeMode.light,
      title: 'Light',
      subtitle: 'Bright and clear, best outdoors in sunlight',
      icon: Icons.light_mode_rounded,
    ),
    (
      mode: ThemeMode.dark,
      title: 'Dark',
      subtitle: 'Easier on the eyes at night, saves battery',
      icon: Icons.dark_mode_rounded,
    ),
    (
      mode: ThemeMode.system,
      title: 'Match system',
      subtitle: 'Follows your phone’s display setting',
      icon: Icons.brightness_auto_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const AppTopBar(title: 'Appearance'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl + context.bottomInset,
        ),
        children: [
          Text('Theme', style: context.text.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose how IrriKart looks on this device.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.mdPlus),
          for (final o in _options) ...[
            _ThemeOptionCard(
              mode: o.mode,
              title: o.title,
              subtitle: o.subtitle,
              icon: o.icon,
              selected: current == o.mode,
              onTap: () => ref.read(themeModeProvider.notifier).set(o.mode),
            ),
            const SizedBox(height: AppSpacing.smd),
          ],
          const SizedBox(height: AppSpacing.sm),
          const InlineBanner(
            tone: Tone.info,
            icon: Icons.info_outline_rounded,
            message: 'Your choice is saved on this phone and applies '
                'right away.',
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title theme',
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.smd),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _ThemePreview(mode: mode),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: selected ? c.onPrimarySoft : c.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            title,
                            style: context.text.title.copyWith(
                              color: selected ? c.onPrimarySoft : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: context.text.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RadioCheck(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioCheck extends StatelessWidget {
  const _RadioCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.primary : c.surface,
        border: Border.all(
          color: selected ? c.primary : c.borderStrong,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: c.textOnPrimary)
          : null,
    );
  }
}

/// A miniature phone screen drawn from blocks in the target theme's own
/// palette — top bar, hero banner, two product tiles, a CTA. "System" is
/// split diagonally: light on the left, dark on the right.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});

  final ThemeMode mode;

  static const double _w = 76;
  static const double _h = 100;

  @override
  Widget build(BuildContext context) {
    final border = context.colors.border;
    final Widget content = switch (mode) {
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

    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        borderRadius: AppRadius.smAll,
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
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

    return ColoredBox(
      color: p.background,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                bar(26, p.textPrimary),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: p.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 22,
              decoration: BoxDecoration(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(4),
              alignment: Alignment.centerLeft,
              child: bar(22, p.primary, h: 5),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border.all(color: p.border, width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: p.surfaceSunken,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            bar(18, p.textSecondary, h: 3),
                            const SizedBox(height: 2),
                            bar(12, p.primary, h: 3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 9,
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: AppRadius.pillAll,
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
