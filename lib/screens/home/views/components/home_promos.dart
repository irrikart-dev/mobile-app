import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

/// One-line "offline" notice: a small warning pill, not a banner block.
class HomeOfflineNotice extends StatelessWidget {
  const HomeOfflineNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: 'Prices and stock may be out of date. Pull down to '
              'refresh once you’re back online.',
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.smd,
              AppSpacing.xs + 2,
              AppSpacing.md,
              AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: c.warningSoft,
              borderRadius: AppRadius.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: AppIconSize.xs,
                  color: c.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Offline · showing saved prices',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(
                      color: c.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three store promises set inline on the canvas — icon + two-line label,
/// no container.
class HomeTrustStrip extends StatelessWidget {
  const HomeTrustStrip({super.key});

  static const _items = [
    (Icons.verified_rounded, 'Genuine\nbrands'),
    (Icons.local_shipping_rounded, 'Fast\ndispatch'),
    (Icons.lock_rounded, 'Secure\npayments'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Row(
                children: [
                  Icon(
                    _items[i].$1,
                    size: AppIconSize.md,
                    color: c.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      _items[i].$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.caption.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bulk-order promo: a sage block with copy and a pill CTA on the left and
/// a geometric brand mosaic bleeding off the right edge. Opens a WhatsApp
/// chat for a quote.
class HomeBulkOrderCard extends StatelessWidget {
  const HomeBulkOrderCard({super.key});

  static const double _artWidth = 104;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: ClipRRect(
        borderRadius: AppRadius.xlAll,
        child: ColoredBox(
          color: c.tint,
          child: Stack(
            children: [
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _artWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(AppRadius.xl),
                  ),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: _artWidth,
                      child: GeoMosaic(variant: 4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.mdPlus,
                  AppSpacing.lg,
                  _artWidth + AppSpacing.mdPlus,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BULK ORDERS',
                      style: context.text.overline.copyWith(
                        color: c.onPrimarySoft,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Buying in bulk?', style: context.text.h2),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Special pricing for farms and FPOs on kits, pipes '
                      'and fittings.',
                      style: context.text.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.mdPlus),
                    AppButton(
                      label: 'Get a quote',
                      icon: Icons.chat_rounded,
                      size: AppButtonSize.sm,
                      expand: false,
                      onPressed: () => openWhatsAppSupport(
                        context,
                        message: 'Hi IrriKart, I would like a quote for a '
                            'bulk order.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
