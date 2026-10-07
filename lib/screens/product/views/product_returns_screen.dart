import 'package:flutter/material.dart';

import '../../../components/ui/ui.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import 'components/quick_facts.dart';

/// Page padding for the policy.
const double _pad = AppSpacing.mdPlus;

/// Return policy, as plain text sections.
///
/// Placeholder copy for the Indian market — real per-product windows come
/// from `isReturnable` / `returnWindowDays` in the catalogue module.
class ProductReturnsScreen extends StatelessWidget {
  const ProductReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const divider = Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl - 4),
      child: Divider(height: 1),
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Returns & refunds'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          _pad,
          AppSpacing.md,
          _pad,
          AppSpacing.xl + context.bottomInset,
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
              child: Icon(
                Icons.assignment_return_rounded,
                color: c.primary,
                size: AppIconSize.lg - 2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.mdPlus),
          Text('7-day easy returns', style: context.text.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'On eligible items, counted from the day of delivery. Here’s '
            'what qualifies and how it works.',
            style: context.text.bodySecondary.copyWith(height: 1.55),
          ),
          const SizedBox(height: AppSpacing.lg),
          const QuickFactsRow(
            facts: [
              QuickFact(
                icon: Icons.event_available_rounded,
                value: '7 days',
                label: 'Window',
              ),
              QuickFact(
                icon: Icons.local_shipping_rounded,
                value: 'Free',
                label: 'Pickup',
              ),
              QuickFact(
                icon: Icons.account_balance_wallet_rounded,
                value: 'Same mode',
                label: 'Refund to',
              ),
            ],
          ),
          divider,
          Text('What can be returned', style: context.text.h3),
          const SizedBox(height: AppSpacing.smd),
          const _Point(
            ok: true,
            text: 'Unused items in their original packaging.',
          ),
          const _Point(
            ok: true,
            text: 'Items that arrive damaged or not as described — report '
                'within 48 hours of delivery with photographs.',
          ),
          divider,
          Text('What can’t be returned', style: context.text.h3),
          const SizedBox(height: AppSpacing.smd),
          const _Point(
            ok: false,
            text: 'Opened seed, fertilizer and crop-protection packs, once the '
                'seal is broken — for safety and traceability.',
          ),
          const _Point(ok: false, text: 'Made-to-order items.'),
          divider,
          Text('How it works', style: context.text.h3),
          const SizedBox(height: AppSpacing.md),
          const _Step(
            n: 1,
            title: 'Contact us',
            text: 'Share your order number and a few photos on WhatsApp.',
          ),
          const _Step(
            n: 2,
            title: 'Free pickup',
            text: 'We schedule a reverse pickup, where serviceable.',
          ),
          const _Step(
            n: 3,
            title: 'Refund',
            text: 'Once inspected, your refund goes to the original payment '
                'method or your IrriKart wallet.',
            last: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
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
    final (fg, bg) = (ok ? Tone.success : Tone.error).resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              size: 13,
              color: fg,
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Text(
              text,
              style: context.text.body.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered step on a thin vertical rail.
class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.text,
    this.last = false,
  });

  final int n;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: context.text.label.copyWith(color: c.textOnPrimary),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md - 2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: last ? 0 : AppSpacing.mdPlus,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.title),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(text, style: context.text.bodySecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
