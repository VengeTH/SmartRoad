import "package:latlong2/latlong.dart";
import "fuel_price.dart";

/// * Fuel station model with community-contributed pricing.
/// *
/// * Stations are either:
/// * - Discovered from OSM (via [MapPoi]) but not yet persisted
/// * - Community-added (verified = false until admin approval)
/// * - Verified by admin (verified = true)
class FuelStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? brand;
  final String province;
  final String city;
  final String? region;
  final bool verified;
  final String source; // "osm", "community"
  final List<FuelPrice> prices;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoUrl;

  const FuelStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.brand,
    required this.province,
    required this.city,
    this.region,
    required this.verified,
    required this.source,
    required this.prices,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
  });

  LatLng get location => LatLng(latitude, longitude);

  /// * Check if any price is stale (older than 24 hours).
  bool get hasStalePrice => prices.any((p) => p.isStale);

  /// * Overall confidence score (average of all prices).
  double get averageConfidence {
    if (prices.isEmpty) return 0.0;
    final sum = prices.fold<double>(0.0, (s, p) => s + p.confidenceScore);
    return sum / prices.length;
  }

  /// * Build from Supabase JSON with embedded prices.
  factory FuelStation.fromJson(Map<String, dynamic> json) {
    final id = (json["id"] ?? "").toString();
    final name = (json["name"] ?? "").toString();

    final latRaw = json["latitude"];
    final lonRaw = json["longitude"];
    final latitude = (latRaw is num) ? latRaw.toDouble() : 0.0;
    final longitude = (lonRaw is num) ? lonRaw.toDouble() : 0.0;

    final brand = json["brand"] as String?;
    final province = json["province"] as String? ?? "";
    final city = json["city"] as String? ?? "";
    final region = json["region"] as String?;

    final verified = json["verified"] as bool? ?? false;
    final source = json["source"] as String? ?? "community";

    final createdAtRaw = json["created_at"] as String?;
    final createdAt = (createdAtRaw != null)
        ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
        : DateTime.now();

    final updatedAtRaw = json["updated_at"] as String?;
    final updatedAt = (updatedAtRaw != null)
        ? DateTime.tryParse(updatedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final photoUrl = json["photo_url"] as String?;

    // Parse embedded prices array
    final pricesRaw = json["prices"];
    final prices = <FuelPrice>[];
    if (pricesRaw is List) {
      for (final item in pricesRaw) {
        if (item is Map<String, dynamic>) {
          prices.add(FuelPrice.fromJson(item));
        }
      }
    }

    return FuelStation(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      brand: brand,
      province: province,
      city: city,
      region: region,
      verified: verified,
      source: source,
      prices: prices,
      createdAt: createdAt,
      updatedAt: updatedAt,
      photoUrl: photoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "latitude": latitude,
      "longitude": longitude,
      if (brand != null) "brand": brand,
      "province": province,
      "city": city,
      if (region != null) "region": region,
      "verified": verified,
      "source": source,
      "prices": prices.map((p) => p.toJson()).toList(),
      "created_at": createdAt.toIso8601String(),
      "updated_at": updatedAt.toIso8601String(),
      if (photoUrl != null) "photo_url": photoUrl,
    };
  }

  /// * Create a copy with updated fields.
  FuelStation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? brand,
    String? province,
    String? city,
    String? region,
    bool? verified,
    String? source,
    List<FuelPrice>? prices,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? photoUrl,
  }) {
    return FuelStation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      brand: brand ?? this.brand,
      province: province ?? this.province,
      city: city ?? this.city,
      region: region ?? this.region,
      verified: verified ?? this.verified,
      source: source ?? this.source,
      prices: prices ?? this.prices,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
