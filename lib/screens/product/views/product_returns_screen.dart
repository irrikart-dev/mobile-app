import 'package:flutter/material.dart';

import '../../../components/ui/ui.dart';
import '../../../core/utils/whatsapp_launcher.dart';

/// Return policy.
///
/// Placeholder copy for the Indian market — real per-product windows come
/// from `isReturnable` / `returnWindowDays` in the catalogue module.
class ProductReturnsScreen extends StatelessWidget {
  const ProductReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: const AppTopBar(title: 'Returns & refunds'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl + context.bottomInset,
        ),
        children: [
          AppCard(
            color: c.primarySoft,
            borderColor: c.primary.withValues(alpha: 0.25),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_return_rounded,
                    color: c.onPrimarySoft,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '7-day easy returns',
                        style: context.text.h3.copyWith(
                          color: c.onPrimarySoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'On eligible items, counted from the day of delivery.',
                        style: context.text.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionCard(
            title: 'At a glance',
            icon: Icons.fact_check_rounded,
            child: Column(
              children: [
                SummaryRow(label: 'Return window', value: '7 days'),
                SummaryRow(label: 'Pickup', value: 'Free, where serviceable'),
                SummaryRow(label: 'Refund to', value: 'Source or wallet'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionCard(
            title: 'What can be returned',
            icon: Icons.check_circle_rounded,
            child: Column(
              children: [
                _Point(
                  ok: true,
                  text: 'Unused items in their original packaging.',
                ),
                _Point(
                  ok: true,
                  text: 'Items that arrive damaged or not as described — '
                      'report within 48 hours of delivery with photographs.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionCard(
            title: 'What cannot be returned',
            icon: Icons.block_rounded,
            child: Column(
              children: [
                _Point(
                  ok: false,
                  text: 'Opened seed, fertilizer and crop-protection packs, '
                      'once the seal is broken — for safety and traceability.',
                ),
                _Point(ok: false, text: 'Made-to-order items.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionCard(
            title: 'How it works',
            icon: Icons.route_rounded,
            child: Column(
              children: [
                _Step(
                  n: 1,
                  text: 'Contact us with your order number and photos.',
                ),
                _Step(n: 2, text: 'We schedule a free reverse pickup.'),
                _Step(
                  n: 3,
                  text: 'Once inspected, your refund is issued to the '
                      'original payment method or IrriKart wallet.',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.outline(
            label: 'Start a return on WhatsApp',
            icon: Icons.chat_rounded,
            onPressed: () => openWhatsAppSupport(
              context,
              message: 'Hi IrriKart, I would like to return an item from my '
                  'order. Order number: ',
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: ok ? c.success : c.error,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.text.body)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.last = false});

  final int n;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.smd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: context.text.badge.copyWith(color: c.onPrimarySoft),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: context.text.body),
            ),
          ),
        ],
      ),
    );
  }
}
