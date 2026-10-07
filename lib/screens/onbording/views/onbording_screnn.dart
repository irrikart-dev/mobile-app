import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../../components/ui/ui.dart';
import '../../../core/storage/local_store.dart';
import '../../../route/route_constants.dart';

class _Slide {
  const _Slide(this.image, this.title, this.description);

  final String image;
  final String title;
  final String description;
}

const _slides = [
  _Slide(
    'assets/Illustration/Illustration-0.svg',
    'The right irrigation gear, made simple',
    'Browse by crop, category or brand with clear specifications, so you '
        'know exactly what you’re buying.',
  ),
  _Slide(
    'assets/Illustration/Illustration-1.svg',
    'Everything your farm needs',
    'Drip kits, sprinklers, pumps, hand tools and more — from trusted '
        'brands, priced right for every acre.',
  ),
  _Slide(
    'assets/Illustration/Illustration-2.svg',
    'Fast, secure payments',
    'Pay by UPI, card or netbanking. Every order is prepaid and protected '
        'end to end.',
  ),
  _Slide(
    'assets/Illustration/Illustration-3.svg',
    'Track every delivery',
    'Follow each order from dispatch to your doorstep, with dates you can '
        'plan the season around.',
  ),
  _Slide(
    'assets/Illustration/Illustration-4.svg',
    'Buying in bulk?',
    'Get a quote for large quantities — for your farm, your village or '
        'your FPO.',
  ),
];

/// First-run introduction. Shown once: finishing or skipping persists the
/// flag (see `LocalStore.onboardingCompleted`) and replaces this route, so
/// neither Back nor a cold start ever brings it back.
class OnBordingScreen extends ConsumerStatefulWidget {
  const OnBordingScreen({super.key});

  @override
  ConsumerState<OnBordingScreen> createState() => _OnBordingScreenState();
}

class _OnBordingScreenState extends ConsumerState<OnBordingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(localStoreProvider).markOnboardingCompleted();
    if (!mounted) return;
    unawaited(Navigator.pushReplacementNamed(context, logInScreenRoute));
  }

  void _next() {
    if (_isLast) {
      unawaited(_finish());
      return;
    }
    unawaited(
      _controller.nextPage(
        duration: AppDurations.normal,
        curve: AppCurves.standard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/logo/irrikart_logo_mark.png',
                      height: 26,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('IrriKart', style: context.text.h3),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: AppDurations.fast,
                      child: IgnorePointer(
                        ignoring: _isLast,
                        child: AppButton.ghost(
                          label: 'Skip',
                          onPressed: _finish,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  _PageDots(count: _slides.length, index: _index),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: _isLast ? 'Get started' : 'Next',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _next,
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

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: AppRadius.xlAll,
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SvgPicture.asset(slide.image, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Natural height; the illustration above absorbs whatever space
          // is left, so short screens shrink the art rather than overflow.
          Text(
            slide.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: context.text.h1,
          ),
          const SizedBox(height: AppSpacing.smd),
          SizedBox(
            height: 64,
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppCurves.standard,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index ? c.primary : c.borderStrong,
              borderRadius: AppRadius.pillAll,
            ),
          ),
      ],
    );
  }
}
