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

/// A product.
///
/// Loaded either from the live API (`GET /api/v1/catalog`) or, when the API is
/// unreachable, from the bundled `assets/mock/products.json`. [fromJson]
/// accepts both shapes: the bundled fixtures predate [id], [sku] and
/// [imageUrl], so those fall back rather than throwing.
///
/// Interim model for the UI revamp — deliberately simpler than the planned
/// `features/catalog` domain (single [price]/[unit] rather than a list of
/// [ProductVariant]s). Field names match where they overlap so this is a
/// straightforward upgrade path, not a rewrite, once the real catalog
/// feature lands.
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.sku,
    required this.slug,
    required this.name,
    required this.category,
    required this.image,
    required this.imageUrl,
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
    required this.source,
  });

  /// Server id. Empty for products read from the bundled fixtures.
  final String id;

  /// Stock keeping unit, editable from the admin dashboard.
  final String sku;

  final String slug;
  final String name;

  /// [CatalogCategory.id] this product belongs to.
  final String category;

  /// Bundled asset path, e.g. `assets/mock/products/img012-….webp`. Null for
  /// products created in the admin dashboard, which carry an [imageUrl].
  final String? image;

  /// Remote image, set on products added from the admin dashboard.
  final String? imageUrl;

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

  /// `seed` for the catalogue carried over from the IrriKart site, `admin`
  /// for anything added in the dashboard. Both render identically; this is
  /// only here for debugging and analytics.
  final String source;

  int get discountPercent =>
      mrp <= price ? 0 : (((mrp - price) / mrp) * 100).round();

  /// True when the image must be fetched over the network rather than read
  /// from the bundle. Drives the `Image.asset` / `CachedNetworkImage` choice.
  bool get hasRemoteImage => image == null && (imageUrl?.isNotEmpty ?? false);

  /// The asset path or URL to render. Prefers the bundled asset — seed
  /// products then display instantly and offline.
  String? get displayImage => image ?? imageUrl;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String?;
    return CatalogProduct(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      slug: json['slug'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      image: (image != null && image.isNotEmpty) ? image : null,
      imageUrl: json['imageUrl'] as String?,
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: ((json['features'] as List?) ?? const []).cast<String>(),
      specs: ((json['specs'] as List?) ?? const [])
          .map((e) => CatalogSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      unit: json['unit'] as String? ?? 'piece',
      mrp: (json['mrp'] as num).toInt(),
      price: (json['price'] as num).toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      inStock: json['inStock'] as bool? ?? true,
      featured: json['featured'] as bool? ?? false,
      source: json['source'] as String? ?? 'seed',
    );
  }
}
