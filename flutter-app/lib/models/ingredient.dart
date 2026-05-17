class IngredientDto {
  IngredientDto({
    this.czechName,
    this.latinName,
    this.cultivar,
    this.speciesId,
    this.percentage,
  });

  final String? czechName;
  final String? latinName;
  final String? cultivar;
  final String? speciesId;
  final num? percentage;

  factory IngredientDto.fromJson(Map<String, dynamic> json) {
    return IngredientDto(
      czechName: json['czechName'] as String?,
      latinName: json['latinName'] as String?,
      cultivar: json['cultivar'] as String?,
      speciesId: json['speciesId'] as String?,
      percentage: json['percentage'] as num?,
    );
  }
}

class Ingredient {
  Ingredient({
    required this.displayName,
    required this.percentage,
    this.latinName,
    this.cultivar,
    this.speciesId,
  });

  final String displayName;
  final double percentage;
  final String? latinName;
  final String? cultivar;
  final String? speciesId;
}

Ingredient ingredientFromDto(IngredientDto dto) {
  final czech = dto.czechName?.trim();
  final latin = dto.latinName?.trim();
  final cultivar = dto.cultivar?.trim();

  // Prefer czech name as primary display, fall back to latin, then a dash.
  final display = (czech != null && czech.isNotEmpty)
      ? czech
      : (latin != null && latin.isNotEmpty ? latin : '—');

  return Ingredient(
    displayName: display,
    percentage: dto.percentage?.toDouble() ?? 0,
    latinName: (latin != null && latin.isNotEmpty) ? latin : null,
    cultivar: (cultivar != null && cultivar.isNotEmpty) ? cultivar : null,
    speciesId: dto.speciesId,
  );
}
