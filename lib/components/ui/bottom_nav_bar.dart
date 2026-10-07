import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/duration_tokens.dart';
import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'badges.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

/// Solid bottom navigation: surface background, top hairline, an animated
/// tinted pill behind the active icon, count badges, and a selection haptic.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.navBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == currentIndex,
                    onTap: () {
                      if (i != currentIndex) HapticFeedback.selectionClick();
                      onTap(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.onPrimarySoft : c.textMuted;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              curve: AppCurves.standard,
              width: active ? 56 : 40,
              height: 30,
              decoration: BoxDecoration(
                color: active ? c.primarySoft : Colors.transparent,
                borderRadius: AppRadius.pillAll,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    active ? item.activeIcon : item.icon,
                    size: 22,
                    color: active ? c.primary : c.textMuted,
                  ),
                  if (item.badge > 0)
                    Positioned(
                      top: -3,
                      right: active ? 8 : 0,
                      child: CountBadge(count: item.badge),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              style: context.text.badge.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
