/// A product category.
///
/// Loaded from the live API (`GET /api/v1/catalog/categories`) or, as a
/// fallback, from the bundled `assets/mock/categories.json`. [fromJson]
/// accepts both shapes.
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.blurb,
    required this.image,
    required this.imageUrl,
    required this.productCount,
  });

  final String id;
  final String slug;
  final String name;
  final String blurb;

  /// Bundled asset path, e.g. `assets/mock/products/img001-….webp`. Set only
  /// on the bundled offline fixtures — the live API never returns this, only
  /// [imageUrl].
  final String? image;

  /// Absolute image URL, as the live API always returns it.
  final String? imageUrl;

  /// Every product in the category, including ones not live — **not** "how
  /// many the user will see." Use the length of the product list for that.
  final int productCount;

  bool get hasRemoteImage => image == null && (imageUrl?.isNotEmpty ?? false);

  /// The asset path or URL to render, preferring the bundled asset.
  String? get displayImage => image ?? imageUrl;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String?;
    return CatalogCategory(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      blurb: json['blurb'] as String? ?? '',
      image: (image != null && image.isNotEmpty) ? image : null,
      imageUrl: json['imageUrl'] as String?,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
    );
  }
}
