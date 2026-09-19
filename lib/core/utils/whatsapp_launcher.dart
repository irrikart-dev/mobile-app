import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';

/// Opens WhatsApp to IrriKart's support number with [message] pre-filled.
/// Shared by every support entry point (the floating button, "Get Help",
/// bulk-order inquiries) so there's exactly one place that knows how to
/// build the `wa.me` link.
Future<void> openWhatsAppSupport(
  BuildContext context, {
  String message = SupportConfig.whatsAppDefaultMessage,
}) async {
  final uri = Uri.https('wa.me', '/${SupportConfig.whatsAppNumber}', {
    'text': message,
  });
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open WhatsApp.')),
    );
  }
}
