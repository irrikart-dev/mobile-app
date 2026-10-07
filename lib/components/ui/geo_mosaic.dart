import 'package:flutter/material.dart';

import '../../core/theme/tokens/color_tokens.dart';

/// Shape a single mosaic tile draws.
enum _Shape {
  square,
  circle,
  quarterTL,
  quarterTR,
  quarterBL,
  quarterBR,
  halfTop,
  halfBottom,
  leaf,
  leafFlip,
  arch,
}

class _Tile {
  const _Tile(this.shape, this.fill, {this.bg, this.icon, this.iconColor});

  final _Shape shape;
  final Color fill;
  final Color? bg;
  final IconData? icon;
  final Color? iconColor;
}

const _f = AppColors.forest;
const _g = AppColors.primary;
const _b = AppColors.secondary;
const _s = AppColors.sun;
const _d = AppColors.sand;
const _v = AppColors.sage;
const _w = AppColors.white;

/// Five hand-composed 3×4 compositions — farming, water, delivery, payments
/// and bulk — built only from flat geometric shapes and a few glyphs, in the
/// brand palette. One per onboarding slide; `0` also heads the sign-in hero.
const _patterns = <List<_Tile>>[
  [
    _Tile(_Shape.quarterBR, _g, bg: _v),
    _Tile(_Shape.square, _f, icon: Icons.eco_rounded, iconColor: _g),
    _Tile(_Shape.circle, _s, bg: _d),
    _Tile(_Shape.leaf, _f, bg: _v),
    _Tile(_Shape.halfBottom, _b, bg: _w, icon: Icons.water_drop_rounded, iconColor: _w),
    _Tile(_Shape.quarterBL, _g, bg: _d),
    _Tile(_Shape.square, _d, icon: Icons.agriculture_rounded, iconColor: _f),
    _Tile(_Shape.arch, _g, bg: _f),
    _Tile(_Shape.leafFlip, _g, bg: _v),
    _Tile(_Shape.quarterTR, _f, bg: _v),
    _Tile(_Shape.halfTop, _s, bg: _d),
    _Tile(_Shape.square, _g, icon: Icons.grass_rounded, iconColor: _f),
  ],
  [
    _Tile(_Shape.circle, _b, bg: _v, icon: Icons.water_drop_rounded, iconColor: _w),
    _Tile(_Shape.quarterBL, _f, bg: _d),
    _Tile(_Shape.leaf, _g, bg: _f),
    _Tile(_Shape.halfBottom, _g, bg: _v),
    _Tile(_Shape.square, _f, icon: Icons.shower_rounded, iconColor: _b),
    _Tile(_Shape.quarterTR, _b, bg: _d),
    _Tile(_Shape.arch, _b, bg: _v),
    _Tile(_Shape.leafFlip, _f, bg: _d),
    _Tile(_Shape.circle, _s, bg: _v),
    _Tile(_Shape.square, _v, icon: Icons.yard_rounded, iconColor: _f),
    _Tile(_Shape.quarterTL, _g, bg: _f),
    _Tile(_Shape.halfTop, _b, bg: _d),
  ],
  [
    _Tile(_Shape.square, _f, icon: Icons.lock_rounded, iconColor: _s),
    _Tile(_Shape.circle, _g, bg: _d),
    _Tile(_Shape.quarterBL, _b, bg: _v),
    _Tile(_Shape.halfTop, _s, bg: _v),
    _Tile(_Shape.leaf, _f, bg: _d),
    _Tile(_Shape.square, _d, icon: Icons.currency_rupee_rounded, iconColor: _f),
    _Tile(_Shape.quarterTR, _g, bg: _f),
    _Tile(_Shape.square, _g, icon: Icons.verified_rounded, iconColor: _w),
    _Tile(_Shape.arch, _f, bg: _v),
    _Tile(_Shape.leafFlip, _g, bg: _d),
    _Tile(_Shape.halfBottom, _b, bg: _v),
    _Tile(_Shape.circle, _s, bg: _f),
  ],
  [
    _Tile(_Shape.halfBottom, _f, bg: _v),
    _Tile(_Shape.square, _s, icon: Icons.local_shipping_rounded, iconColor: _f),
    _Tile(_Shape.quarterBR, _g, bg: _d),
    _Tile(_Shape.circle, _b, bg: _d),
    _Tile(_Shape.arch, _g, bg: _v),
    _Tile(_Shape.leaf, _f, bg: _v),
    _Tile(_Shape.square, _f, icon: Icons.location_on_rounded, iconColor: _g),
    _Tile(_Shape.quarterTL, _s, bg: _d),
    _Tile(_Shape.halfTop, _g, bg: _v),
    _Tile(_Shape.leafFlip, _g, bg: _d),
    _Tile(_Shape.circle, _g, bg: _f),
    _Tile(_Shape.square, _v, icon: Icons.inventory_2_rounded, iconColor: _f),
  ],
  [
    _Tile(_Shape.square, _g, icon: Icons.groups_rounded, iconColor: _w),
    _Tile(_Shape.quarterBR, _f, bg: _d),
    _Tile(_Shape.circle, _s, bg: _v),
    _Tile(_Shape.leafFlip, _f, bg: _v),
    _Tile(_Shape.halfBottom, _g, bg: _d),
    _Tile(_Shape.square, _f, icon: Icons.handshake_rounded, iconColor: _s),
    _Tile(_Shape.arch, _b, bg: _d),
    _Tile(_Shape.quarterTL, _g, bg: _f),
    _Tile(_Shape.leaf, _g, bg: _v),
    _Tile(_Shape.square, _d, icon: Icons.agriculture_rounded, iconColor: _f),
    _Tile(_Shape.halfTop, _f, bg: _v),
    _Tile(_Shape.circle, _b, bg: _d),
  ],
];

/// Flat geometric brand illustration: a 3×4 mosaic of shapes and glyphs.
/// Fills its width; height follows at 4:3 (rows:columns). Pick a
/// composition with [variant] (0–4).
class GeoMosaic extends StatelessWidget {
  const GeoMosaic({super.key, this.variant = 0, this.gap = 0});

  final int variant;
  final double gap;

  static const int columns = 3;
  static const int rows = 4;

  @override
  Widget build(BuildContext context) {
    final tiles = _patterns[variant % _patterns.length];
    return AspectRatio(
      aspectRatio: columns / rows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final t in tiles)
                SizedBox.square(dimension: size, child: _TileView(tile: t)),
            ],
          );
        },
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxWidth;
        final r = Radius.circular(s);
        final shape = switch (tile.shape) {
          _Shape.square => const BoxDecoration(),
          _Shape.circle => const BoxDecoration(shape: BoxShape.circle),
          _Shape.quarterTL => BoxDecoration(borderRadius: BorderRadius.only(bottomRight: r)),
          _Shape.quarterTR => BoxDecoration(borderRadius: BorderRadius.only(bottomLeft: r)),
          _Shape.quarterBL => BoxDecoration(borderRadius: BorderRadius.only(topRight: r)),
          _Shape.quarterBR => BoxDecoration(borderRadius: BorderRadius.only(topLeft: r)),
          _Shape.halfTop => BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(s / 2)),
            ),
          _Shape.halfBottom => BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(s / 2)),
            ),
          _Shape.leaf => BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: r, bottomRight: r),
            ),
          _Shape.leafFlip => BoxDecoration(
              borderRadius: BorderRadius.only(topRight: r, bottomLeft: r),
            ),
          _Shape.arch => BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(s / 2)),
            ),
        };

        final inset = switch (tile.shape) {
          _Shape.circle => s * 0.12,
          _Shape.arch => s * 0.16,
          _ => 0.0,
        };

        return ColoredBox(
          color: tile.bg ?? tile.fill,
          child: Padding(
            padding: tile.shape == _Shape.arch
                ? EdgeInsets.fromLTRB(inset, inset, inset, 0)
                : EdgeInsets.all(inset),
            child: DecoratedBox(
              decoration: shape.copyWith(color: tile.fill),
              child: tile.icon == null
                  ? const SizedBox.expand()
                  : Center(
                      child: Icon(
                        tile.icon,
                        size: s * 0.42,
                        color: tile.iconColor,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
