/// A single named specification row (e.g. "Flow Rate" -> "2 – 8 LPH").
class CatalogSpec {
  const CatalogSpec({required this.label, required this.value});

  final String label;
  final String value;

  factory CatalogSpec.fromJson(Map<String, dynamic> json) {
    return CatalogSpec(
      label: json['label'] as String,
      value: json['value'] as String,
    );
  }
}

/// A product, loaded from `assets/mock/products.json`.
///
/// Interim model for the UI revamp — deliberately simpler than the planned
/// `features/catalog` domain (single [price]/[unit] rather than a list of
/// [ProductVariant]s). Field names match where they overlap so this is a
/// straightforward upgrade path, not a rewrite, once the real catalog
/// feature lands.
class CatalogProduct {
  const CatalogProduct({
    required this.slug,
    required this.name,
    required this.category,
    required this.image,
    required this.tagline,
    required this.description,
    required this.features,
    required this.specs,
    required this.unit,
    required this.mrp,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.inStock,
    required this.featured,
  });

  final String slug;
  final String name;

  /// [CatalogCategory.id] this product belongs to.
  final String category;

  /// Local asset path.
  final String image;

  final String tagline;
  final String description;
  final List<String> features;
  final List<CatalogSpec> specs;

  /// Pack unit label: `piece`, `set`, `roll`, ... See `PackUnit` in the
  /// catalog domain plan for the full enum this will become.
  final String unit;

  /// Whole rupees. MRP and selling price, not paise — money-as-paise lands
  /// with the real payments feature; this mock layer keeps it simple.
  final int mrp;
  final int price;

  final double rating;
  final int reviewCount;
  final bool inStock;
  final bool featured;

  int get discountPercent =>
      mrp <= price ? 0 : (((mrp - price) / mrp) * 100).round();

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      slug: json['slug'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      image: json['image'] as String,
      tagline: json['tagline'] as String,
      description: json['description'] as String,
      features: (json['features'] as List).cast<String>(),
      specs: (json['specs'] as List)
          .map((e) => CatalogSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      unit: json['unit'] as String,
      mrp: json['mrp'] as int,
      price: json['price'] as int,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['reviewCount'] as int,
      inStock: json['inStock'] as bool,
      featured: json['featured'] as bool,
    );
  }
}
