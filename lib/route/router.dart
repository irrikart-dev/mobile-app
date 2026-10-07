import 'package:flutter/material.dart';
import 'package:irrikart/entry_point.dart';
import 'package:irrikart/models/address_data.dart';
import 'package:irrikart/models/order_data.dart';

import 'screen_export.dart';

/// Every named route in the app. Tab roots (Home, Categories, Orders,
/// Account) live inside [EntryPoint]; Cart and Orders also have their own
/// routes so they can be pushed from elsewhere with a back button.
Route<dynamic> generateRoute(RouteSettings settings) {
  Route<T> page<T>(WidgetBuilder builder) =>
      MaterialPageRoute<T>(builder: builder, settings: settings);

  switch (settings.name) {
    case onbordingScreenRoute:
      return page((_) => const OnBordingScreen());
    case logInScreenRoute:
    case signUpScreenRoute:
      // One screen, Google-only — Firebase treats a new and a returning
      // account identically, so there is nothing left to tell apart.
      return page((_) => const AuthScreen());
    case entryPointScreenRoute:
      return page((_) => const EntryPoint());
    case productDetailsScreenRoute:
      return page((_) => ProductDetailsScreen(slug: settings.arguments as String));
    case productListScreenRoute:
      return page(
        (_) => ProductListScreen(categoryId: settings.arguments as String),
      );
    case productReviewsScreenRoute:
      return page(
        (_) => ProductReviewsScreen(
          args: settings.arguments as ProductReviewsArgs,
        ),
      );
    case productReturnsScreenRoute:
      return page((_) => const ProductReturnsScreen());
    case searchScreenRoute:
      return page((_) => const SearchScreen());
    case bookmarkScreenRoute:
      return page((_) => const BookmarkScreen());
    case userInfoScreenRoute:
      return page((_) => const UserInfoScreen());
    case preferencesScreenRoute:
      return page((_) => const PreferencesScreen());
    case addressesScreenRoute:
      return page((_) => const AddressesScreen());
    case addNewAddressesScreenRoute:
      return page(
        (_) => AddEditAddressScreen(existing: settings.arguments as Address?),
      );
    case cartScreenRoute:
      return page((_) => const CartScreen());
    case checkoutScreenRoute:
      return page((_) => const CheckoutScreen());
    case orderProcessingScreenRoute:
      return page(
        (_) => OrderProcessingScreen(
          args: settings.arguments as OrderProcessingArgs,
        ),
      );
    case thanksForOrderScreenRoute:
      return page(
        (_) => ThanksForOrderScreen(order: settings.arguments as Order),
      );
    case ordersScreenRoute:
      return page((_) => const OrdersScreen());
    case orderDetailsScreenRoute:
      return page(
        (_) => OrderDetailScreen(orderId: settings.arguments as String),
      );
    default:
      // Unknown route name — land somewhere safe rather than crash.
      return page((_) => const EntryPoint());
  }
}
