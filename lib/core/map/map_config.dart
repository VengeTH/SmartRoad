/// * SmartRoad Map — Configuration
/// *
/// * Controls which map implementation is active.
/// * Allows gradual migration from FlutterMap → MapLibre.
/// * Set [useMapLibre] to true to enable the new implementation.
import 'package:flutter/foundation.dart';

/// * Map implementation provider
abstract class MapConfig {
  /// * Toggle between FlutterMap (false) and MapLibre (true)
  /// * Set to true after MapLibre implementation is validated
  static bool get useMapLibre => _useMapLibre;
  static bool _useMapLibre = true;

  /// * Enable MapLibre (call this once at app startup after validation)
  static void enableMapLibre() {
    _useMapLibre = true;
    debugPrint('🗺️ [MapConfig] Switched to MapLibre implementation');
  }

  /// * Fall back to FlutterMap
  static void disableMapLibre() {
    _useMapLibre = false;
    debugPrint('🗺️ [MapConfig] Switched to FlutterMap implementation');
  }

  /// * MapLibre access token (if needed by the style)
  static const String mapLibreAccessToken = '';

  /// * Default map style URL for MapLibre
  static const String mapLibreStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
  // * Demo (basic): 'https://demotiles.maplibre.org/style.json'
  // * Custom: 'https://maps.smartroad.ph/styles/default/style.json'

  /// * OpenStreetMap tile URL (fallback for FlutterMap)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// * Philippines-focused bounds
  static const double philippinesSouth = 4.5;
  static const double philippinesNorth = 21.5;
  static const double philippinesWest = 116.0;
  static const double philippinesEast = 128.0;

  /// * Default camera position (Manila)
  static const double defaultLatitude = 14.5995;
  static const double defaultLongitude = 120.9842;
  static const double defaultZoom = 12.0;
  static const double minZoom = 4.0;
  static const double maxZoom = 19.0;

  /// * Navigation zoom level
  static const double navigationZoom = 16.8;
}
