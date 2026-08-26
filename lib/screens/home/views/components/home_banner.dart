import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/radius_tokens.dart';
import '../../../../core/theme/tokens/shadow_tokens.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';

class _Slide {
  const _Slide({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

const _slides = [
  _Slide(
    title: 'Drip kits, ready to install',
    subtitle: 'Complete farm kits from ₹2,209',
    icon: Icons.grass_outlined,
  ),
  _Slide(
    title: 'Free delivery over ₹999',
    subtitle: 'On sprinklers, filters & valves',
    icon: Icons.local_shipping_outlined,
  ),
  _Slide(
    title: 'Bulk order? Get a quote',
    subtitle: 'Special pricing for farms & FPOs',
    icon: Icons.request_quote_outlined,
  ),
];

/// The home screen's rotating promo banner. Matches the reference theme's
/// `home-banner` carousel (auto-advancing slides with dot indicators).
class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  final _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: AppRadius.lgAll,
                  boxShadow: AppShadows.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slide.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            slide.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      slide.icon,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.25),
                  borderRadius: AppRadius.pillAll,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
