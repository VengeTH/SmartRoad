/// * Traffic Layer
/// * Raster tile layer for live traffic visualization
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "../config/traffic_config.dart";

/// * Traffic Layer using TomTom traffic tiles
/// * 
/// * TomTom provides traffic flow tiles
/// * URL format: https://api.tomtom.com/traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?key={apiKey}
/// * 
/// * Free tier: 2,500 requests/day
/// * Get free API key: https://developer.tomtom.com/
/// * Documentation: https://developer.tomtom.com/traffic-api/traffic-flow/flow-tiles
class TrafficLayer extends TileLayer {
  final bool enabled;
  final double opacity;
  
  TrafficLayer({
    required this.enabled,
    this.opacity = 0.7,
  }) : super(
    urlTemplate: TrafficConfig.getTrafficTileUrl(0, 0, 0), // * Will be replaced by tileProvider
    userAgentPackageName: "com.smartroad.app",
    maxZoom: 18,
    minZoom: 2,
    tileProvider: TrafficTileProvider(),
    // * Apply opacity in tileBuilder
    // * TomTom traffic tiles are transparent PNG overlays
    tileBuilder: (context, tileWidget, tile) {
      if (!enabled) {
        // * Return transparent tile if disabled
        return const SizedBox.shrink();
      }
      return Opacity(
        opacity: opacity,
        child: tileWidget,
      );
    },
  );
}

/// * Traffic Tile Provider
/// * Provides tiles from TomTom Traffic Flow API
class TrafficTileProvider extends TileProvider {
  TrafficTileProvider();
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    try {
      final apiKey = TrafficConfig.tomtomApiKey;
      if (apiKey.isEmpty) {
        // * Return transparent placeholder if no API key
        return const NetworkImage("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");
      }
      
      // * CRITICAL: Convert coordinates to integers (z, x, y in that order)
      // * TomTom API rejects floating-point numbers
      final z = coordinates.z.toInt();
      final x = coordinates.x.toInt();
      final y = coordinates.y.toInt();
      
      final url = TrafficConfig.getTrafficTileUrl(z, x, y);
      
      // * Removed verbose logging to prevent console overflow
      // * Traffic tile loading is handled silently by flutter_map
      
      // * Return NetworkImage - errors will be handled by flutter_map
      return NetworkImage(url);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [TrafficTileProvider] Error generating URL: $e");
      }
      // * Return transparent placeholder on error
      return const NetworkImage("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");
    }
  }
}

