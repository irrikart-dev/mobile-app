import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';
import '../../../rfq/views/quote_requests_screen.dart';

/// "Buying in bulk?" dealer-inquiry block — one sage tint panel that opens
/// the bulk quote form (`POST /rfq`) prefilled with this product.
class BulkOrderCard extends StatelessWidget {
  const BulkOrderCard({
    super.key,
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

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
              'Get dealer pricing on larger quantities — tell us what you '
              'need and our team will get back to you.',
              style: context.text.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md + 2),
            AppButton(
              label: 'Request a bulk quote',
              icon: Icons.request_quote_rounded,
              size: AppButtonSize.md,
              expand: false,
              onPressed: () => showQuoteRequestSheet(
                context,
                productId: productId,
                productName: productName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
