import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'components/glass/glass_bottom_nav.dart';
import 'models/cart_state.dart';
import 'route/screen_export.dart';

/// The tabbed shell: Home, Categories, Cart, Orders, Account — matching the
/// reference theme's bottom-tab-bar exactly (`xr` in its bundle). Wishlist
/// and Search are one tap away (from Home's app bar and product hearts)
/// rather than tabs of their own, same as the reference.
class EntryPoint extends ConsumerStatefulWidget {
  const EntryPoint({super.key});

  @override
  ConsumerState<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends ConsumerState<EntryPoint> {
  int _currentIndex = 0;

  static const _pages = [
    HomeScreen(),
    DiscoverScreen(),
    CartScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    GlassNavItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    GlassNavItem(
      icon: Icon(Icons.grid_view_outlined),
      activeIcon: Icon(Icons.grid_view_rounded),
      label: 'Categories',
    ),
    GlassNavItem(
      icon: Icon(Icons.shopping_bag_outlined),
      activeIcon: Icon(Icons.shopping_bag),
      label: 'Cart',
    ),
    GlassNavItem(
      icon: Icon(Icons.receipt_long_outlined),
      activeIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    GlassNavItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartTotalItemsProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: GlassBottomNav(
        items: [
          for (var i = 0; i < _items.length; i++)
            if (i == 2 && cartCount > 0)
              GlassNavItem(
                icon: _CartIconWithBadge(count: cartCount, filled: false),
                activeIcon: _CartIconWithBadge(count: cartCount, filled: true),
                label: 'Cart',
              )
            else
              _items[i],
        ],
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _CartIconWithBadge extends StatelessWidget {
  const _CartIconWithBadge({required this.count, required this.filled});

  final int count;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(filled ? Icons.shopping_bag : Icons.shopping_bag_outlined),
        Positioned(
          top: -6,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
