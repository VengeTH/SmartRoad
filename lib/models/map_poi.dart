import "package:latlong2/latlong.dart";

/// * Lightweight POI model for map-only landmarks (from Nominatim).
/// *
/// * NOTE: This is separate from [Place] because these POIs are not tied to
/// * Supabase community features (photos/likes/comments).
class MapPoi {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? type;
  final String? category;
  final double? importance;
  final String? addressLine;

  const MapPoi({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type,
    this.category,
    this.importance,
    this.addressLine,
  });

  LatLng get location => LatLng(latitude, longitude);
}

