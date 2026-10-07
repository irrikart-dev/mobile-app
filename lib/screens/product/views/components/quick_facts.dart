import 'package:flutter/material.dart';

import '../../../../components/ui/ui.dart';

/// One at-a-glance fact: an icon, a short value and what it means.
class QuickFact {
  const QuickFact({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

/// A row of small sage tiles (icon + value + label) — the PDP's "at a
/// glance" strip, also used on the returns policy. Tiles share the width
/// equally, so keep it to three or four facts.
class QuickFactsRow extends StatelessWidget {
  const QuickFactsRow({super.key, required this.facts});

  final List<QuickFact> facts;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.smd - 2),
              Expanded(child: _FactTile(fact: facts[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final QuickFact fact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: '${fact.label}: ${fact.value}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.tint, borderRadius: AppRadius.lgAll),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.smd + 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fact.icon, size: AppIconSize.md, color: c.primary),
              const SizedBox(height: AppSpacing.smd - 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  fact.value,
                  maxLines: 1,
                  style: context.text.titleSm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                fact.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.captionMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
