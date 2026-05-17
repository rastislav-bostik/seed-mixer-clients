import 'ingredient.dart';
import 'offering.dart';

/// DTO mirroring the server's `ProductSummary` (the lightweight shape returned
/// by `GET /products`). No `description` or `composition` — see [ProductDto]
/// for the full record from `GET /products/{source}/{slug}`.
class ProductSummaryDto {
  ProductSummaryDto({
    this.id,
    this.source,
    this.manufacturer,
    this.slug,
    this.name,
    this.categories,
    this.url,
    this.tags,
    this.images,
    this.offerings,
    this.observedAt,
    this.type,
    this.speciesCount,
  });

  final String? id;
  final String? source;
  final String? manufacturer;
  final String? slug;
  final String? name;
  final List<String>? categories;
  final String? url;
  final List<String>? tags;
  final List<String>? images;
  final List<OfferingDto>? offerings;
  final String? observedAt;
  final String? type;
  final int? speciesCount;

  factory ProductSummaryDto.fromJson(Map<String, dynamic> json) {
    return ProductSummaryDto(
      id: json['id'] as String?,
      source: json['source'] as String?,
      manufacturer: json['manufacturer'] as String?,
      slug: json['slug'] as String?,
      name: json['name'] as String?,
      categories: _stringList(json['categories']),
      url: json['url'] as String?,
      tags: _stringList(json['tags']),
      images: _stringList(json['images']),
      offerings: _dtoList(json['offerings'], OfferingDto.fromJson),
      observedAt: json['observedAt'] as String?,
      type: json['type'] as String?,
      speciesCount: (json['speciesCount'] as num?)?.toInt(),
    );
  }
}

/// Full product detail from `GET /products/{source}/{slug}`. Server returns
/// a `oneOf mixture|species` union — we flatten it: `type` discriminates.
class ProductDto {
  ProductDto({
    this.id,
    this.source,
    this.manufacturer,
    this.slug,
    this.name,
    this.categories,
    this.description,
    this.url,
    this.tags,
    this.images,
    this.composition,
    this.offerings,
    this.observedAt,
    this.type,
    this.warnings,
  });

  final String? id;
  final String? source;
  final String? manufacturer;
  final String? slug;
  final String? name;
  final List<String>? categories;
  final String? description;
  final String? url;
  final List<String>? tags;
  final List<String>? images;
  final List<IngredientDto>? composition;
  final List<OfferingDto>? offerings;
  final String? observedAt;
  final String? type;
  final List<String>? warnings;

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    return ProductDto(
      id: json['id'] as String?,
      source: json['source'] as String?,
      manufacturer: json['manufacturer'] as String?,
      slug: json['slug'] as String?,
      name: json['name'] as String?,
      categories: _stringList(json['categories']),
      description: json['description'] as String?,
      url: json['url'] as String?,
      tags: _stringList(json['tags']),
      images: _stringList(json['images']),
      composition: _dtoList(json['composition'], IngredientDto.fromJson),
      offerings: _dtoList(json['offerings'], OfferingDto.fromJson),
      observedAt: json['observedAt'] as String?,
      type: json['type'] as String?,
      warnings: _stringList(json['_warnings']),
    );
  }
}

/// Domain model used by every screen.
class Product {
  Product({
    required this.id,
    required this.source,
    required this.slug,
    required this.name,
    required this.manufacturer,
    required this.type,
    required this.categories,
    required this.tags,
    required this.images,
    required this.offerings,
    required this.composition,
    this.description,
    this.url,
    this.observedAt,
  });

  final String id;
  final String source;
  final String slug;
  final String name;
  final String manufacturer;
  final ProductType type;
  final List<String> categories;
  final List<String> tags;
  final List<String> images;
  final List<Offering> offerings;
  final List<Ingredient> composition;
  final String? description;
  final String? url;
  final String? observedAt;

  bool get hasImage => images.isNotEmpty;
  String? get primaryImage => hasImage ? images.first : null;

  /// Cheapest non-null pack price. Useful for the list view's "od XXX Kč".
  double? get lowestPriceCzk {
    final candidates = offerings
        .map((o) => o.priceCzk)
        .whereType<double>()
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }

  /// Total composition coverage (sum of percentages). When < 100 it means the
  /// scraper didn't capture every ingredient — useful as a data-quality hint.
  double get compositionCoveragePercent {
    return composition.fold<double>(0, (sum, i) => sum + i.percentage);
  }
}

enum ProductType { mixture, species, unknown }

ProductType _parseType(String? raw) {
  switch (raw) {
    case 'mixture':
      return ProductType.mixture;
    case 'species':
      return ProductType.species;
    default:
      return ProductType.unknown;
  }
}

Product productFromSummaryDto(ProductSummaryDto dto) {
  return Product(
    id: dto.id ?? '',
    source: dto.source ?? '',
    slug: dto.slug ?? '',
    name: dto.name?.trim().isNotEmpty == true ? dto.name!.trim() : '—',
    manufacturer: dto.manufacturer?.trim() ?? '',
    type: _parseType(dto.type),
    categories: dto.categories ?? const [],
    tags: dto.tags ?? const [],
    images: dto.images ?? const [],
    offerings: (dto.offerings ?? const []).map(offeringFromDto).toList(),
    composition: const [], // not present on summary
    description: null,
    url: dto.url,
    observedAt: dto.observedAt,
  );
}

Product productFromDetailDto(ProductDto dto) {
  return Product(
    id: dto.id ?? '',
    source: dto.source ?? '',
    slug: dto.slug ?? '',
    name: dto.name?.trim().isNotEmpty == true ? dto.name!.trim() : '—',
    manufacturer: dto.manufacturer?.trim() ?? '',
    type: _parseType(dto.type),
    categories: dto.categories ?? const [],
    tags: dto.tags ?? const [],
    images: dto.images ?? const [],
    offerings: (dto.offerings ?? const []).map(offeringFromDto).toList(),
    composition: (dto.composition ?? const []).map(ingredientFromDto).toList(),
    description: dto.description?.trim().isNotEmpty == true ? dto.description!.trim() : null,
    url: dto.url,
    observedAt: dto.observedAt,
  );
}

List<String>? _stringList(dynamic v) {
  if (v is! List) return null;
  return v.whereType<String>().toList();
}

List<T>? _dtoList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return null;
  // Web's jsonDecode returns Map<String, Object?>, VM returns Map<String, dynamic>.
  // `whereType<Map>()` accepts both; then we coerce element type explicitly.
  return v
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .map(fromJson)
      .toList();
}
