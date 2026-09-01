/// A product category.
///
/// Loaded from the API (`GET /api/v1/catalog`) or, as a fallback, from the
/// bundled `assets/mock/categories.json`. [fromJson] accepts both shapes.
///
/// Interim model for the UI revamp. Field names intentionally match the
/// `Category` entity planned for `features/catalog/domain` so this can be
/// swapped for the real freezed/Riverpod catalog feature without renaming
/// call sites.
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.blurb,
    required this.image,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String blurb;

  /// Bundled asset path, e.g. `assets/mock/products/img001-….webp`. Null for
  /// categories created in the admin dashboard.
  final String? image;

  /// Remote image, set on categories added from the admin dashboard.
  final String? imageUrl;

  bool get hasRemoteImage => image == null && (imageUrl?.isNotEmpty ?? false);

  /// The asset path or URL to render, preferring the bundled asset.
  String? get displayImage => image ?? imageUrl;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String?;
    return CatalogCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      blurb: json['blurb'] as String? ?? '',
      image: (image != null && image.isNotEmpty) ? image : null,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
