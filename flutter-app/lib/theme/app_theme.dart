import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loads `assets/tokens.json` (mirror of `shared/design-tokens/tokens.json`)
/// at app start and exposes a [ThemeData] derived from it.
///
/// Token shape is loosely DTCG — `{ "$value": "...", "$type": "..." }`. We
/// only read what we need; unknown keys are ignored.
class AppTokens {
  AppTokens._(this._data);

  final Map<String, dynamic> _data;

  static Future<AppTokens> load() async {
    final raw = await rootBundle.loadString('assets/tokens.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AppTokens._(decoded);
  }

  Color color(String path, {Color fallback = const Color(0xFF000000)}) {
    final hex = _readString(['color', ...path.split('.')]);
    if (hex == null) return fallback;
    return _parseHex(hex) ?? fallback;
  }

  double spacing(String key, {double fallback = 8}) {
    final raw = _readString(['spacing', key]);
    return double.tryParse(raw ?? '') ?? fallback;
  }

  double radius(String key, {double fallback = 8}) {
    final raw = _readString(['radius', key]);
    return double.tryParse(raw ?? '') ?? fallback;
  }

  double fontSize(String key, {double fallback = 14}) {
    final raw = _readString(['typography', 'fontSize', key]);
    return double.tryParse(raw ?? '') ?? fallback;
  }

  String? _readString(List<String> path) {
    dynamic node = _data;
    for (final segment in path) {
      if (node is! Map<String, dynamic>) return null;
      node = node[segment];
    }
    if (node is! Map<String, dynamic>) return null;
    final value = node[r'$value'];
    return value is String ? value : null;
  }

  Color? _parseHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final intVal = int.tryParse(cleaned, radix: 16);
    if (intVal == null) return null;
    return Color(0xFF000000 | intVal);
  }
}

ThemeData buildTheme(AppTokens tokens) {
  final meadow = tokens.color('brand.meadow', fallback: const Color(0xFF5B8C4F));
  final bloom = tokens.color('brand.bloom', fallback: const Color(0xFFE8A33A));
  final surface = tokens.color('neutral.surface', fallback: const Color(0xFFFAFAF7));
  final ink = tokens.color('neutral.ink', fallback: const Color(0xFF1A1A1A));

  final colorScheme = ColorScheme.fromSeed(
    seedColor: meadow,
    primary: meadow,
    secondary: bloom,
    surface: surface,
    onSurface: ink,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius('md', fallback: 12)),
        side: BorderSide(color: tokens.color('neutral.line', fallback: const Color(0xFFE5E5E5))),
      ),
    ),
  );
}
