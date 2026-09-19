import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/radius_tokens.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

/// "Buying in bulk?" dealer-inquiry trigger — hands off to WhatsApp with a
/// message pre-filled for this product, rather than a custom quote-request
/// flow/backend this app doesn't have yet.
class BulkOrderButton extends StatelessWidget {
  const BulkOrderButton({
    super.key,
    required this.productName,
    required this.sku,
  });

  final String productName;
  final String sku;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: () => openWhatsAppSupport(
        context,
        message: 'Hi IrriKart, I would like a bulk/wholesale quote for '
            '"$productName" (SKU: $sku). Please share pricing for larger quantities.',
      ),
      icon: const Icon(Icons.request_quote_outlined, size: 18),
      label: const Text('Buying in bulk? Get a dealer quote'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        side: BorderSide(color: theme.colorScheme.primary),
        foregroundColor: theme.colorScheme.primary,
      ),
    );
  }
}
