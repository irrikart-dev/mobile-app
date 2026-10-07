import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

/// Compact three-up row of store promises, in a card.
class HomeTrustStrip extends StatelessWidget {
  const HomeTrustStrip({super.key});

  static const _items = [
    (Icons.verified_rounded, 'Genuine brands'),
    (Icons.local_shipping_rounded, 'Fast dispatch'),
    (Icons.lock_rounded, 'Secure prepaid payments'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) VerticalDivider(width: 1, color: c.divider),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _items[i].$1,
                          size: AppIconSize.sm,
                          color: c.onPrimarySoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Text(
                          _items[i].$2,
                          maxLines: 2,
                          textAlign: TextAlign.center,
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
        ),
      ),
    );
  }
}

/// "Buying for a farm?" card — opens a WhatsApp chat for a bulk quote.
class HomeBulkOrderCard extends StatelessWidget {
  const HomeBulkOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.mdPlus),
        decoration: BoxDecoration(
          color: c.secondarySoft,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BULK ORDERS',
                    style: context.text.overline.copyWith(color: c.secondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Buying for a farm or FPO?', style: context.text.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Get special pricing on drip kits, pipes and fittings — '
                    'our team replies on WhatsApp.',
                    style: context.text.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Get a bulk quote',
                    icon: Icons.chat_rounded,
                    size: AppButtonSize.sm,
                    expand: false,
                    onPressed: () => openWhatsAppSupport(
                      context,
                      message:
                          'Hi IrriKart, I would like a quote for a bulk order.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                size: AppIconSize.lg,
                color: c.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
