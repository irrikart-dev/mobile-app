import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

/// "Buying in bulk?" dealer-inquiry block — one sage tint panel that hands
/// off to WhatsApp with a message pre-filled for this product, rather than a
/// quote-request backend this app doesn't have yet.
class BulkOrderCard extends StatelessWidget {
  const BulkOrderCard({
    super.key,
    required this.productName,
    required this.sku,
  });

  final String productName;
  final String sku;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.tint, borderRadius: AppRadius.xlAll),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mdPlus,
          AppSpacing.mdPlus + 2,
          AppSpacing.mdPlus,
          AppSpacing.mdPlus,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOR FARMS & PROJECTS',
              style: context.text.overline.copyWith(color: c.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Buying in bulk?', style: context.text.h2),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'Get dealer pricing on larger quantities — chat with our '
              'team on WhatsApp.',
              style: context.text.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md + 2),
            AppButton(
              label: 'Get a bulk quote',
              icon: Icons.chat_rounded,
              size: AppButtonSize.md,
              expand: false,
              onPressed: () => openWhatsAppSupport(
                context,
                message: 'Hi IrriKart, I would like a bulk/wholesale quote for '
                    '"$productName" (SKU: $sku). Please share pricing for '
                    'larger quantities.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
