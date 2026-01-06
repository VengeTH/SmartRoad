import "package:latlong2/latlong.dart";

/// * Known place / landmark model (used for location previews).
/// *
/// * This model is used for:
/// * - Built-in known locations (loaded from assets/known_places.json)
/// * - Supabase-backed community content (photos, likes, comments) keyed by [id]
class Place {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? category;
  final List<String> aliases;

  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    this.aliases = const [],
  });

  LatLng get location => LatLng(latitude, longitude);

  /// * Build a [Place] from JSON.
  /// *
  /// * Supported keys:
  /// * - id (String)
  /// * - name (String)
  /// * - latitude (num)
  /// * - longitude (num)
  /// * - category (String?)
  /// * - aliases (List<String>?)
  factory Place.fromJson(Map<String, dynamic> json) {
    final id = (json["id"] ?? "").toString().trim();
    final name = (json["name"] ?? "").toString().trim();
    final latRaw = json["latitude"];
    final lonRaw = json["longitude"];

    final latitude = (latRaw is num) ? latRaw.toDouble() : double.nan;
    final longitude = (lonRaw is num) ? lonRaw.toDouble() : double.nan;

    final aliasesRaw = json["aliases"];
    final aliases = <String>[];
    if (aliasesRaw is List) {
      for (final item in aliasesRaw) {
        final value = item?.toString().trim();
        if (value != null && value.isNotEmpty) {
          aliases.add(value);
        }
      }
    }

    return Place(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      category: (json["category"] as String?)?.trim(),
      aliases: aliases,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "latitude": latitude,
      "longitude": longitude,
      if (category != null) "category": category,
      if (aliases.isNotEmpty) "aliases": aliases,
    };
  }
}

