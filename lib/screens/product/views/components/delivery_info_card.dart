import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Delivery, payment and returns promises as plain icon rows — no frame.
class DeliveryInfoCard extends StatelessWidget {
  const DeliveryInfoCard({super.key, required this.onReturnsTap});

  final VoidCallback onReturnsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PdpIconRow(
          icon: Icons.local_shipping_rounded,
          title: 'Dispatch in 24–48 hrs',
          subtitle: 'Tracked delivery to farms, towns and cities across India',
        ),
        const PdpIconRow(
          icon: Icons.verified_user_rounded,
          title: 'Secure prepaid payment',
          subtitle: 'UPI, cards and netbanking',
        ),
        PdpIconRow(
          icon: Icons.assignment_return_rounded,
          title: '7-day easy returns',
          subtitle: 'On eligible items · See policy',
          onTap: onReturnsTap,
        ),
      ],
    );
  }
}

/// Sage icon disc + title + supporting line, optionally tappable. The PDP's
/// building block for lightweight info rows.
class PdpIconRow extends StatelessWidget {
  const PdpIconRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
            child: Icon(icon, size: AppIconSize.sm + 2, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.title),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: context.text.caption),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(trailingIcon, color: c.textMuted, size: AppIconSize.md - 2),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: row,
    );
  }
}
