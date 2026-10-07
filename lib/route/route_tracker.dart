import 'package:flutter/widgets.dart';

/// App-wide navigator handle — for redirects that originate outside any
/// screen (e.g. the session ending while the user is mid-app).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Name of the page route currently on top, for chrome that must hide itself
/// on some screens (the WhatsApp button over onboarding, sign-in, checkout).
final currentRouteName = ValueNotifier<String?>(null);

/// Number of popup routes (sheets, dialogs, menus) currently open — floating
/// chrome hides while any is up so it never sits on top of a modal.
final openPopupCount = ValueNotifier<int>(0);

class RouteTracker extends NavigatorObserver {
  void _show(Route<dynamic>? route) {
    if (route is PopupRoute) return;
    final name = route?.settings.name;
    if (name != null) currentRouteName.value = name;
  }

  void _popupDelta(Route<dynamic> route, int delta) {
    if (route is PopupRoute) {
      openPopupCount.value = (openPopupCount.value + delta).clamp(0, 99);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popupDelta(route, 1);
    _show(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popupDelta(route, -1);
    _show(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _popupDelta(oldRoute, -1);
    if (newRoute != null) _popupDelta(newRoute, 1);
    _show(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popupDelta(route, -1);
    _show(previousRoute);
  }
}
