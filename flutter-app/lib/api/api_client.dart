import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper for the seed-mixer backend.
///
/// Three responsibilities only:
///   1. Resolve the right base URL for the current target (web, sim, emulator).
///   2. Decode JSON with a generous timeout (Render free tier cold-starts).
///   3. Retry once on transient failure before surfacing an error.
///
/// Everything beyond that — DTO shapes, mapping to domain models, caching —
/// lives in the model layer. Keep this file boring.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
        _client = client ?? http.Client();

  static const String _prodBaseUrl = 'https://seed-mixer-api.onrender.com';

  /// First request after Render cold sleep can take 30–60 s. Subsequent calls
  /// should be quick, so we keep the per-request timeout high and let the UI
  /// show a "warming up" hint instead of failing fast.
  static const Duration _requestTimeout = Duration(seconds: 70);

  final String _baseUrl;
  final http.Client _client;

  String get baseUrl => _baseUrl;

  static String _resolveDefaultBaseUrl() {
    // Allow override via --dart-define=API_BASE_URL=...
    const overridden = String.fromEnvironment('API_BASE_URL');
    if (overridden.isNotEmpty) return overridden;

    // Default to production. Local dev users pass --dart-define explicitly.
    return _prodBaseUrl;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(_baseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// GET JSON with one retry on network error or 5xx. Surfaces structured
  /// [ApiException] on failure — never throws a raw `HttpException` into the
  /// UI layer.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);

    Future<http.Response> attempt() =>
        _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(_requestTimeout);

    http.Response response;
    try {
      response = await attempt();
      if (response.statusCode >= 500) {
        // Single retry on 5xx. No backoff — backend is either warming up
        // (and the second call will be quick) or genuinely down.
        response = await attempt();
      }
    } on TimeoutException {
      throw ApiException(
        message: 'Backend took too long to respond. It may be warming up — try again in a moment.',
        statusCode: null,
      );
    } catch (e) {
      throw ApiException(message: 'Network error: $e', statusCode: null);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: _decodeErrorMessage(response.body) ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Unexpected response shape: ${decoded.runtimeType}',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  String? _decodeErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Body wasn't JSON; fall through.
    }
    return null;
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  ApiException({required this.message, required this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Helper for clients that want to surface a "this is the first call, it might
/// be slow" hint. Render cold-start is the common cause.
bool isLikelyColdStart(Object error) {
  if (error is! ApiException) return false;
  return error.statusCode == null && error.message.contains('warming up');
}
