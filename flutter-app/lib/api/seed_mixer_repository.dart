import '../models/product.dart';
import 'api_client.dart';

/// Higher-level API on top of [ApiClient]. Knows about endpoints, DTOs, and
/// mapping to domain models — but nothing about UI state or caching policy.
class SeedMixerRepository {
  SeedMixerRepository(this._client);

  final ApiClient _client;

  String get baseUrl => _client.baseUrl;

  /// `GET /products?type=mixture` (or other filter combo).
  Future<List<Product>> listProducts({
    String? type,
    String? manufacturer,
    String? source,
    String? category,
  }) async {
    final query = <String, dynamic>{};
    if (type != null) query['type'] = type;
    if (manufacturer != null) query['manufacturer'] = manufacturer;
    if (source != null) query['source'] = source;
    if (category != null) query['category'] = category;

    final response = await _client.getJson('/products', query: query.isEmpty ? null : query);
    final rawProducts = response['products'];
    if (rawProducts is! List) return const [];

    return rawProducts
        .whereType<Map<String, dynamic>>()
        .map(ProductSummaryDto.fromJson)
        .map(productFromSummaryDto)
        .toList();
  }

  /// `GET /products/{source}/{slug}` — full detail with composition.
  Future<Product> getProduct(String source, String slug) async {
    final response = await _client.getJson('/products/$source/$slug');
    final dto = ProductDto.fromJson(response);
    return productFromDetailDto(dto);
  }
}
