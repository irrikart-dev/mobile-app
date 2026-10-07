@Tags(['shots'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/entry_point.dart';
import 'package:irrikart/entry_point_tab.dart';
import 'package:irrikart/models/address_data.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:irrikart/models/order_data.dart';
import 'package:irrikart/models/wishlist_state.dart';
import 'package:irrikart/screens/address/views/add_edit_address_screen.dart';
import 'package:irrikart/screens/address/views/addresses_screen.dart';
import 'package:irrikart/screens/preferences/views/preferences_screen.dart';
import 'package:irrikart/screens/profile/views/account_providers.dart';
import 'package:irrikart/screens/user_info/views/user_info_screen.dart';

import 'harness.dart';

class _FakeProvider extends Fake implements UserInfo {
  @override
  String get providerId => 'google.com';
}

class _FakeUser extends Fake implements User {
  @override
  String? get displayName => 'Ravi Kumar Patil';
  @override
  String? get email => 'ravi.patil@gmail.com';
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => [_FakeProvider()];
}

const _addresses = [
  Address(
    id: 'a1',
    name: 'Ravi Kumar Patil',
    phone: '9876543210',
    line1: 'Gat no. 214, Patil Farm, Ozar Road',
    line2: 'Near Gram Panchayat office',
    city: 'Niphad, Nashik',
    state: 'Maharashtra',
    pincode: '422206',
    isDefault: true,
  ),
  Address(
    id: 'a2',
    name: 'Sunita Patil',
    phone: '919822012345',
    line1: 'Plot 7, Shivaji Nagar',
    line2: null,
    city: 'Pune',
    state: 'Maharashtra',
    pincode: '411005',
    isDefault: false,
  ),
  Address(
    id: 'a3',
    name: 'Godown — Patil Agro',
    phone: '9922334455',
    line1: 'MIDC Sinnar, Shed B-12',
    line2: null,
    city: 'Sinnar',
    state: 'Maharashtra',
    pincode: '422103',
    isDefault: false,
  ),
];

class _FakeAddresses extends AddressController {
  @override
  Future<List<Address>> build() async => _addresses;
}

class _FakeWishlist extends WishlistController {
  @override
  Set<String> build() => {'a', 'b', 'c', 'd', 'e'};
}

final _user = _FakeUser();

List<Override> get _signedIn => [
      accountUserProvider.overrideWith((ref) => Stream.value(_user)),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      addressControllerProvider.overrideWith(_FakeAddresses.new),
      wishlistControllerProvider.overrideWith(_FakeWishlist.new),
      appVersionProvider.overrideWith((ref) async => '1.4.0 (23)'),
      orderHistoryProvider.overrideWith(
        (ref) async => [
          for (var i = 0; i < 12; i++)
            OrderSummary(
              id: 'o$i',
              orderNumber: 'IK-10$i',
              status: OrderStatus.delivered,
              rawStatus: 'DELIVERED',
              amount: 1200,
              currency: 'INR',
              createdAt: DateTime(2026, 9, 1),
            ),
        ],
      ),
      catalogDataProvider.overrideWith((ref) => CatalogData.loadBundled()),
    ];

/// Shows [child] as a pushed route so it gets a real back button.
class _Pushed extends StatefulWidget {
  const _Pushed(this.child);

  final Widget child;

  @override
  State<_Pushed> createState() => _PushedState();
}

class _PushedState extends State<_Pushed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => widget.child),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

void main() {
  setUpAll(loadShotFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'account $dark',
      (t) => shot(
        t,
        'account',
        const EntryPoint(),
        dark: dark,
        overrides: [
          ..._signedIn,
          entryTabIndexProvider.overrideWith((ref) => 4),
        ],
      ),
    );
    testWidgets(
      'account scrolled $dark',
      (t) => shot(
        t,
        'account_scrolled',
        const EntryPoint(),
        dark: dark,
        overrides: [
          ..._signedIn,
          entryTabIndexProvider.overrideWith((ref) => 4),
        ],
        before: (t) async {
          // Let any push transition finish (its first frame is offstage).
          await t.pump(const Duration(milliseconds: 500));
          await t.drag(find.byType(ListView).last, const Offset(0, -600));
          await t.pump();
        },
      ),
    );
    testWidgets(
      'account guest $dark',
      (t) => shot(
        t,
        'account_guest',
        const EntryPoint(),
        dark: dark,
        overrides: [
          catalogDataProvider.overrideWith((ref) => CatalogData.loadBundled()),
          entryTabIndexProvider.overrideWith((ref) => 4),
        ],
      ),
    );
    testWidgets(
      'details $dark',
      (t) => shot(
        t,
        'details',
        const _Pushed(UserInfoScreen()),
        dark: dark,
        overrides: _signedIn,
      ),
    );
    testWidgets(
      'appearance $dark',
      (t) => shot(
        t,
        'appearance',
        const _Pushed(PreferencesScreen()),
        dark: dark,
        overrides: _signedIn,
      ),
    );
    testWidgets(
      'addresses $dark',
      (t) => shot(
        t,
        'addresses',
        const _Pushed(AddressesScreen()),
        dark: dark,
        overrides: _signedIn,
      ),
    );
    testWidgets(
      'add address $dark',
      (t) => shot(
        t,
        'add_address',
        const _Pushed(AddEditAddressScreen()),
        dark: dark,
        overrides: _signedIn,
      ),
    );
    testWidgets(
      'edit address $dark',
      (t) => shot(
        t,
        'edit_address',
        _Pushed(AddEditAddressScreen(existing: _addresses.first)),
        dark: dark,
        overrides: _signedIn,
      ),
    );
    testWidgets(
      'edit address scrolled $dark',
      (t) => shot(
        t,
        'edit_address_scrolled',
        _Pushed(AddEditAddressScreen(existing: _addresses[1])),
        dark: dark,
        overrides: _signedIn,
        before: (t) async {
          // Let any push transition finish (its first frame is offstage).
          await t.pump(const Duration(milliseconds: 500));
          await t.drag(find.byType(ListView).last, const Offset(0, -600));
          await t.pump();
        },
      ),
    );
  }
}
