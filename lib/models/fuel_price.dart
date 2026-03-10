import "fuel_type.dart";

/// * Single fuel type price at a station.
class FuelPrice {
  final FuelType fuelType;
  final double price;
  final DateTime updatedAt;
  final String source; // "community", "official", "osm"
  final double confidenceScore; // 0.0 - 1.0
  final bool isStale; // true if older than 24 hours

  const FuelPrice({
    required this.fuelType,
    required this.price,
    required this.updatedAt,
    required this.source,
    required this.confidenceScore,
    required this.isStale,
  });

  /// * Build from Supabase JSON.
  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    final fuelTypeKey = json["fuel_type"] as String? ?? "";
    final fuelType = FuelType.fromDbKey(fuelTypeKey) ?? FuelType.unleaded91;

    final priceRaw = json["price"];
    final price = (priceRaw is num) ? priceRaw.toDouble() : 0.0;

    final updatedAtRaw = json["updated_at"] as String?;
    final updatedAt = (updatedAtRaw != null)
        ? DateTime.tryParse(updatedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final source = json["source"] as String? ?? "community";

    final confidenceRaw = json["confidence_score"];
    final confidenceScore =
        (confidenceRaw is num) ? confidenceRaw.toDouble() : 1.0;

    final now = DateTime.now();
    final isStale = now.difference(updatedAt).inHours >= 24;

    return FuelPrice(
      fuelType: fuelType,
      price: price,
      updatedAt: updatedAt,
      source: source,
      confidenceScore: confidenceScore,
      isStale: isStale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "fuel_type": fuelType.dbKey,
      "price": price,
      "updated_at": updatedAt.toIso8601String(),
      "source": source,
      "confidence_score": confidenceScore,
    };
  }
}
