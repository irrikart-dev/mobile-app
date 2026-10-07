import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// Delivery, payment and returns promises, as icon rows in one card.
class DeliveryInfoCard extends StatelessWidget {
  const DeliveryInfoCard({super.key, required this.onReturnsTap});

  final VoidCallback onReturnsTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _InfoRow(
            icon: Icons.local_shipping_rounded,
            title: 'Dispatch in 24–48 hrs',
            subtitle: 'Packed and handed to our courier partner',
          ),
          Divider(height: 1, color: c.divider, indent: 64),
          const _InfoRow(
            icon: Icons.public_rounded,
            title: 'Delivery across India',
            subtitle: 'Tracked shipping to farms, towns and cities',
          ),
          Divider(height: 1, color: c.divider, indent: 64),
          const _InfoRow(
            icon: Icons.verified_user_rounded,
            title: 'Secure prepaid payment',
            subtitle: 'UPI, cards and netbanking',
          ),
          Divider(height: 1, color: c.divider, indent: 64),
          _InfoRow(
            icon: Icons.assignment_return_rounded,
            title: 'Easy returns',
            subtitle: '7-day returns on eligible items',
            onTap: onReturnsTap,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 18, color: c.onPrimarySoft),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSm),
                const SizedBox(height: 2),
                Text(subtitle, style: context.text.captionMuted),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 20),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
