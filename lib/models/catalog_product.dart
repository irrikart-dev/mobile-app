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

/// One purchasable size/pack option of a product (`ProductVariant` on the
/// backend). Every product has at least one — [CatalogProduct.variantId]
/// always points at `variants.first`, so screens that don't care about
/// options keep working unmodified.
class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.sku,
    required this.size,
    required this.color,
    required this.unit,
    required this.price,
    required this.stockQty,
    required this.available,
  });

  final String id;
  final String sku;
  final String? size;
  final String? color;
  final String unit;
  final num price;
  final int stockQty;

  /// `stockQty` minus what other orders already have reserved — this, not
  /// [stockQty], is what actually caps how many can be added to cart.
  final int available;

  bool get buyable => available > 0;

  /// Chip label shown in the variant selector — falls back to the unit when
  /// there's no size/color set, so every variant still reads as something.
  String get label => size ?? color ?? unit;

  factory CatalogVariant.fromJson(Map<String, dynamic> json) {
    final stockQty = (json['stockQty'] as num?)?.toInt() ?? 0;
    return CatalogVariant(
      id: json['id'] as String,
      sku: json['sku'] as String? ?? '',
      size: json['size'] as String?,
      color: json['color'] as String?,
      unit: json['unit'] as String? ?? 'piece',
      price: (json['price'] as num?) ?? 0,
      stockQty: stockQty,
      available: (json['available'] as num?)?.toInt() ?? stockQty,
    );
  }
}

/// A product.
///
/// Loaded either from the live API (`GET /api/v1/catalog/products*`) or, when
/// the API is unreachable, from the bundled `assets/mock/products.json`.
/// [fromJson] accepts both shapes: the bundled fixtures predate [id] and
/// [imageUrl], so those fall back rather than throwing.
///
/// There is deliberately no `mrp`/`discountPercent`/`featured` here — the
/// backend removed all three from the catalogue contract on 2026-09-11.
/// There is one price, no discount concept (that returns as its own
/// promotions feature later), and no home-screen pin flag (a category rail
/// replaces it).
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.variantId,
    required this.sku,
    required this.slug,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.image,
    required this.imageUrl,
    this.images = const [],
    this.videoUrl,
    this.variants = const [],
    required this.tagline,
    required this.description,
    required this.features,
    required this.specs,
    required this.unit,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.inStock,
    required this.stockQty,
  });

  /// Stable primary key — a product, **not** a cart line. Use [variantId] for
  /// `POST /cart/items`; this id is a different table and the cart API
  /// rejects it with "Product variant not found."
  final String id;

  /// What the cart API actually keys off — single-variant-per-product model,
  /// so this is a 1:1 stand-in for the product from the app's point of view,
  /// but it is a genuinely different id server-side. Empty string on the
  /// bundled offline fixtures (they predate this field entirely); the "Add
  /// to cart" flow always re-fetches the live product first regardless (see
  /// `CatalogData.fetchFreshProduct`), so this only matters online.
  final String variantId;

  /// Human-readable code, shown in support flows. May change if an admin
  /// edits it.
  final String sku;

  /// URL-safe, used for deep links.
  final String slug;

  final String name;

  /// [CatalogCategory.id] this product belongs to.
  final String category;

  /// Denormalised category name, for list rendering with no second call.
  final String categoryName;

  /// Bundled asset path, e.g. `assets/mock/products/img012-….webp`. Set only
  /// on the bundled offline fixtures — the live API never returns this, only
  /// [imageUrl].
  final String? image;

  /// Absolute image URL, as the live API always returns it. `null` means no
  /// image — render a placeholder.
  final String? imageUrl;

  /// Full gallery, absolute URLs, position-ordered — empty on the bundled
  /// offline fixtures. [displayImage] (`images.first`, effectively) stays the
  /// single image every other screen renders; the PDP is the only place that
  /// reads the rest.
  final List<String> images;

  /// YouTube URL for the PDP's demo-video slot, if the admin set one.
  final String? videoUrl;

  /// Every purchasable size/pack option. Always has at least one entry once
  /// loaded from the live API — [variantId]/[price]/[stockQty] mirror
  /// `variants.first` for screens that don't need the rest.
  final List<CatalogVariant> variants;

  final String tagline;
  final String description;
  final List<String> features;
  final List<CatalogSpec> specs;

  /// Pack unit label: `piece`, `set`, `roll`, `pack`, `box`, `metre`, `kg`,
  /// `litre`.
  final String unit;

  /// Selling price, INR. A JSON number with up to 2 decimal places — never
  /// cache this across sessions; always re-read it before checkout.
  final num price;

  final double rating;
  final int reviewCount;

  /// The admin's manual "In stock" switch.
  final bool inStock;

  /// Units on hand. Can be `> 0` while [inStock] is `false`.
  final int stockQty;

  /// Show "Add to cart" only when this is true — [inStock] **and**
  /// [stockQty] `> 0`. Either alone being falsy means display-only.
  bool get buyable => inStock && stockQty > 0;

  /// True when the image must be fetched over the network rather than read
  /// from the bundle. Drives the `Image.asset` / `CachedNetworkImage` choice.
  bool get hasRemoteImage => image == null && (imageUrl?.isNotEmpty ?? false);

  /// The asset path or URL to render. Prefers the bundled asset — offline
  /// fixtures then display instantly and without a network call.
  String? get displayImage => image ?? imageUrl;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String?;
    final inStock = json['inStock'] as bool? ?? true;
    return CatalogProduct(
      id: json['id'] as String? ?? '',
      variantId: json['variantId'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      slug: json['slug'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      image: (image != null && image.isNotEmpty) ? image : null,
      imageUrl: json['imageUrl'] as String?,
      images: ((json['images'] as List?) ?? const []).cast<String>(),
      videoUrl: json['videoUrl'] as String?,
      variants: ((json['variants'] as List?) ?? const [])
          .map((e) => CatalogVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: ((json['features'] as List?) ?? const []).cast<String>(),
      specs: ((json['specs'] as List?) ?? const [])
          .map((e) => CatalogSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      unit: json['unit'] as String? ?? 'piece',
      price: (json['price'] as num?) ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      inStock: inStock,
      // The bundled offline fixtures predate stockQty entirely — assume
      // "plenty" when the admin's switch says in stock, none otherwise, so
      // the buyability rule still behaves sensibly offline.
      stockQty: (json['stockQty'] as num?)?.toInt() ?? (inStock ? 999 : 0),
    );
  }
}
