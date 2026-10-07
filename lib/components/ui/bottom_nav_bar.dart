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

/// Floating forest-green pill navigation. Inactive tabs are icons only; the
/// active tab expands into a light pill with its label. Used with
/// `Scaffold.extendBody` so content scrolls underneath it.
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
    final inset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        inset + AppSpacing.navFloatGap,
      ),
      child: Container(
        height: AppSpacing.navBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c.navBar,
          borderRadius: AppRadius.pillAll,
          boxShadow: c.shadowFloating,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == currentIndex ? 2 : 1,
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
    final activeBg = context.isDark ? c.accent : c.surface;
    final activeFg = context.isDark ? c.background : c.navBar;
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          active ? item.activeIcon : item.icon,
          size: 22,
          color: active ? activeFg : c.onNavBar.withValues(alpha: 0.72),
        ),
        if (item.badge > 0)
          Positioned(
            top: -6,
            right: -9,
            child: CountBadge(count: item.badge),
          ),
      ],
    );

    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppCurves.emphasized,
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: active ? 14 : 0),
            decoration: BoxDecoration(
              color: active ? activeBg : Colors.transparent,
              borderRadius: AppRadius.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (active) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: context.text.label.copyWith(
                        color: activeFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
