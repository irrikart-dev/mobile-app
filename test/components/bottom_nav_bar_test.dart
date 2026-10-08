import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/components/ui/bottom_nav_bar.dart';
import 'package:irrikart/core/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets('nav fits at $width dp with every tab active', (t) async {
      t.view.physicalSize = Size(width * 3, 2000);
      t.view.devicePixelRatio = 3;
      for (var i = 0; i < 5; i++) {
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                currentIndex: i,
                onTap: (_) {},
                items: const [
                  NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home'),
                  NavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Categories'),
                  NavItem(
                      icon: Icons.shopping_bag_outlined,
                      activeIcon: Icons.shopping_bag_rounded,
                      label: 'Cart',
                      badge: 3),
                  NavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Orders'),
                  NavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Account'),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'tab $i at $width');
      }
    });
  }
}
