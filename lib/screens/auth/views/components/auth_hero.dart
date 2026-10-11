import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/theme/tokens/color_tokens.dart';

/// Deep-green top of the sign-in screen: the white IrriKart lockup over a
/// fixed-ratio brand banner. Same in light and dark mode on purpose — it's
/// the brand moment.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  /// The banner's design size, at the 390 dp reference width. It always
  /// spans the full screen width at this aspect ratio (~2.17 : 1), so its
  /// height is deterministic and a client-supplied banner can replace the
  /// mosaic with `Image.asset(..., fit: BoxFit.cover)` and no layout change.
  /// Export such an image at 1170 × 540 px (@3x), keeping the important
  /// content inside the centre 300 dp in case of narrower phones.
  static const bannerDesignSize = Size(390, 180);

  static const _logoHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.forest, AppColors.forestDark],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: top + AppSpacing.smd),
          Image.asset(
            'assets/logo/irrikart_logo_full_white.png',
            height: _logoHeight,
            semanticLabel: 'IrriKart',
          ),
          const SizedBox(height: AppSpacing.smd),
          AspectRatio(
            aspectRatio: bannerDesignSize.aspectRatio,
            child: const _MosaicBanner(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Placeholder banner art until the client supplies an image: the brand
/// [GeoMosaic], centred at the banner's full height.
class _MosaicBanner extends StatelessWidget {
  const _MosaicBanner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AspectRatio(
        aspectRatio: GeoMosaic.columns / GeoMosaic.rows,
        child: ClipRRect(
          borderRadius: AppRadius.xlAll,
          child: GeoMosaic(),
        ),
      ),
    );
  }
}
