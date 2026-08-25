import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';

/// A softer input border for search and inline fields, where the standard
/// filled [InputDecorationTheme] would be too heavy.
///
/// Replaces the template's `secodaryOutlineInputBorder` (sic).
OutlineInputBorder secondaryOutlineInputBorder(BuildContext context) {
  return OutlineInputBorder(
    borderRadius: AppRadius.mdAll,
    borderSide: BorderSide(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
    ),
  );
}
