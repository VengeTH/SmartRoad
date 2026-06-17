/// * SmartRoad Map Abstraction — Shared Types
/// *
/// * Defines platform-agnostic coordinate and geometry types
/// * that decouple app features from any specific map SDK.

/// * Geographic coordinate (lat/lon)
class MapCoord {
  final double latitude;
  final double longitude;

  const MapCoord(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapCoord &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'MapCoord($latitude, $longitude)';

  MapCoord copyWith({double? latitude, double? longitude}) =>
      MapCoord(latitude ?? this.latitude, longitude ?? this.longitude);
}

/// * Geographic bounding box
class MapBounds {
  final double south;
  final double west;
  final double north;
  final double east;

  const MapBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  bool contains(MapCoord coord) =>
      coord.latitude >= south &&
      coord.latitude <= north &&
      coord.longitude >= west &&
      coord.longitude <= east;

  MapCoord get center => MapCoord((south + north) / 2, (west + east) / 2);

  double get latitudeSpan => north - south;
  double get longitudeSpan => east - west;
}

/// * Camera position state
class MapCameraPosition {
  final MapCoord center;
  final double zoom;
  final double bearing; // degrees, 0 = north
  final double tilt; // degrees from vertical

  const MapCameraPosition({
    required this.center,
    required this.zoom,
    this.bearing = 0.0,
    this.tilt = 0.0,
  });

  MapCameraPosition copyWith({
    MapCoord? center,
    double? zoom,
    double? bearing,
    double? tilt,
  }) => MapCameraPosition(
    center: center ?? this.center,
    zoom: zoom ?? this.zoom,
    bearing: bearing ?? this.bearing,
    tilt: tilt ?? this.tilt,
  );
}

/// * Map style definition
class MapStyle {
  final String uri;

  const MapStyle(this.uri);

  /// * OpenStreetMap raster tiles (fallback / dev)
  static const MapStyle osmLight = MapStyle(
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// * MapLibre demo tiles (basic OSM vector style)
  static const MapStyle maplibreBasic = MapStyle(
    'https://demotiles.maplibre.org/style.json',
  );

  /// * OpenFreeMap vector tiles (good default for production)
  static const MapStyle openFreeMap = MapStyle(
    'https://tiles.openfreemap.org/styles/liberty',
  );

  /// * Custom SmartRoad style (future: self-hosted)
  static const MapStyle smartRoad = MapStyle(
    'https://maps.smartroad.ph/styles/default/style.json',
  );
}

/// * Feature ID type
typedef FeatureId = String;

/// * Generic map feature with optional properties
class MapFeature<T> {
  final FeatureId id;
  final T data;
  final Map<String, dynamic> properties;

  const MapFeature({
    required this.id,
    required this.data,
    this.properties = const {},
  });
}

/// * Animation duration for camera movements
enum MapAnimationDuration {
  instant(0),
  fast(200),
  normal(400),
  slow(800);

  final int milliseconds;
  const MapAnimationDuration(this.milliseconds);
}
