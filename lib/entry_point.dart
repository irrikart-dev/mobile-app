import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'components/ui/bottom_nav_bar.dart';
import 'entry_point_tab.dart';
import 'models/cart_state.dart';
import 'route/screen_export.dart';

/// The tabbed shell: Home, Categories, Cart, Orders, Account. Wishlist and
/// Search are one tap away from Home's header.
///
/// Back on a non-Home tab returns to Home instead of leaving the app.
class EntryPoint extends ConsumerWidget {
  const EntryPoint({super.key});

  static const _pages = [
    HomeScreen(),
    DiscoverScreen(),
    CartScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartTotalItemsProvider);
    final currentIndex = ref.watch(entryTabIndexProvider);
    final setTab = ref.read(entryTabIndexProvider.notifier);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setTab.state = 0;
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: currentIndex, children: _pages),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: currentIndex,
          onTap: (i) => setTab.state = i,
          items: [
            const NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            const NavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: 'Categories',
            ),
            NavItem(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag_rounded,
              label: 'Cart',
              badge: cartCount,
            ),
            const NavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Orders',
            ),
            const NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
