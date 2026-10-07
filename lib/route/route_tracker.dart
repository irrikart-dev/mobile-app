import 'package:flutter/widgets.dart';

/// App-wide navigator handle — for redirects that originate outside any
/// screen (e.g. the session ending while the user is mid-app).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Name of the route currently on top, for chrome that must hide itself on
/// some screens (the WhatsApp button over onboarding, sign-in, checkout).
final currentRouteName = ValueNotifier<String?>(null);

class RouteTracker extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) currentRouteName.value = name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _update(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);
}
