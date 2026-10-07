import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

/// "Buying in bulk?" dealer-inquiry card — hands off to WhatsApp with a
/// message pre-filled for this product, rather than a quote-request backend
/// this app doesn't have yet.
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
    return AppCard(
      color: c.primarySoft,
      borderColor: c.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: c.onPrimarySoft,
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buying for a farm or project?',
                      style: context.text.title.copyWith(
                        color: c.onPrimarySoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get dealer pricing on larger quantities — chat with '
                      'our team on WhatsApp.',
                      style: context.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          AppButton(
            label: 'Get a bulk quote',
            icon: Icons.chat_rounded,
            size: AppButtonSize.md,
            onPressed: () => openWhatsAppSupport(
              context,
              message: 'Hi IrriKart, I would like a bulk/wholesale quote for '
                  '"$productName" (SKU: $sku). Please share pricing for '
                  'larger quantities.',
            ),
          ),
        ],
      ),
    );
  }
}
