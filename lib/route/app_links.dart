import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalog_data.dart';
import '../screens/rfq/views/quote_requests_screen.dart';
import 'route_constants.dart';

/// Opens an admin-authored link — a banner CTA or a campaign push.
///
/// App routes: `/category/<id|slug>`, `/product/<slug|id>`,
/// `/order/<id>`, `/orders`, `/notifications`, `/rfq`. `http(s)` links open
/// in the browser. Anything else is ignored.
Future<void> openAppLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return;
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  final nav = Navigator.of(context);
  switch (uri.pathSegments) {
    case ['category' || 'categories', final hint]:
      final catalog = ProviderScope.containerOf(context, listen: false)
          .read(catalogDataProvider)
          .valueOrNull;
      await nav.pushNamed(
        productListScreenRoute,
        arguments: _categoryId(catalog, hint),
      );
    case ['product' || 'products', final slug]:
      await nav.pushNamed(productDetailsScreenRoute, arguments: slug);
    case ['order' || 'orders', final id]:
      await nav.pushNamed(orderDetailsScreenRoute, arguments: id);
    case ['orders']:
      await nav.pushNamed(ordersScreenRoute);
    case ['notifications']:
      await nav.pushNamed(notificationsScreenRoute);
    case ['rfq' || 'bulk' || 'quote']:
      await showQuoteRequestSheet(context);
  }
}

/// Exact id/slug first, then a loose match so `/category/kits` still finds
/// "drip-kits" after a re-slug.
String _categoryId(CatalogData? catalog, String hint) {
  final categories = catalog?.categories ?? const [];
  final h = hint.toLowerCase();
  for (final c in categories) {
    if (c.id == hint || c.slug == hint) return c.id;
  }
  for (final c in categories) {
    if (c.slug.toLowerCase().contains(h) || c.name.toLowerCase().contains(h)) {
      return c.id;
    }
  }
  return hint;
}
