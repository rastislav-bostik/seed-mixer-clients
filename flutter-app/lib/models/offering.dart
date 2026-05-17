/// Raw shape mirroring the server's `Offering` schema. Every field is
/// optional / nullable — the mapper handles defaults. Tolerant on purpose:
/// unknown fields are ignored, missing fields don't crash.
class OfferingDto {
  OfferingDto({
    this.packLabel,
    this.weightGrams,
    this.priceCzk,
    this.priceCzkExclVat,
    this.pricePerKgCzk,
    this.vatPercent,
    this.inStock,
    this.notes,
  });

  final String? packLabel;
  final num? weightGrams;
  final num? priceCzk;
  final num? priceCzkExclVat;
  final num? pricePerKgCzk;
  final num? vatPercent;
  final bool? inStock;
  final String? notes;

  factory OfferingDto.fromJson(Map<String, dynamic> json) {
    return OfferingDto(
      packLabel: json['packLabel'] as String?,
      weightGrams: json['weightGrams'] as num?,
      priceCzk: json['priceCzk'] as num?,
      priceCzkExclVat: json['priceCzkExclVat'] as num?,
      pricePerKgCzk: json['pricePerKgCzk'] as num?,
      vatPercent: json['vatPercent'] as num?,
      inStock: json['inStock'] as bool?,
      notes: json['notes'] as String?,
    );
  }
}

/// What the UI actually renders. Sensible defaults, no nulls in display fields.
class Offering {
  Offering({
    required this.packLabel,
    this.weightGrams,
    this.priceCzk,
    this.pricePerKgCzk,
    this.inStock,
    this.notes,
  });

  final String packLabel;
  final double? weightGrams;
  final double? priceCzk;
  final double? pricePerKgCzk;
  final bool? inStock;
  final String? notes;
}

Offering offeringFromDto(OfferingDto dto) {
  return Offering(
    packLabel: dto.packLabel?.trim().isNotEmpty == true ? dto.packLabel!.trim() : '—',
    weightGrams: dto.weightGrams?.toDouble(),
    priceCzk: dto.priceCzk?.toDouble(),
    pricePerKgCzk: dto.pricePerKgCzk?.toDouble(),
    inStock: dto.inStock,
    notes: dto.notes?.trim().isNotEmpty == true ? dto.notes!.trim() : null,
  );
}
