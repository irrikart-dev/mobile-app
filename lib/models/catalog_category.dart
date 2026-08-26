/// A product category, loaded from `assets/mock/categories.json`.
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
  });

  final String id;
  final String name;
  final String blurb;

  /// Local asset path, e.g. `assets/mock/products/img001-....webp`.
  final String image;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      blurb: json['blurb'] as String,
      image: json['image'] as String,
    );
  }
}
