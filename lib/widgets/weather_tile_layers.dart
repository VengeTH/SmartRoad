/// * Weather Tile Layers
/// * Raster tile layer implementations for weather visualization
import "dart:math" as math;
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../services/weather_layer_manager.dart";
import "../services/weather_tile_generator.dart";
import "../config/weather_config.dart";

/// * Rain Layer using OpenWeatherMap precipitation tiles
/// * 
/// * OpenWeatherMap provides precipitation/rain radar tiles
/// * URL format: https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={apiKey}
/// * 
/// * Get free API key from: https://openweathermap.org/api
/// * Free tier: 1,000 calls/day, 60 calls/minute
class RainLayer extends TileLayer {
  final WeatherLayerManager manager;
  
  RainLayer({
    required this.manager,
  }) : super(
    urlTemplate: WeatherConfig.getOpenWeatherMapRainTileUrl(0, 0, 0), // * Will be replaced by tileProvider
    userAgentPackageName: "com.smartroad.app",
    maxZoom: 18, // * Match map maxZoom to keep layer visible at all zoom levels
    minZoom: 2,
    tileProvider: OpenWeatherMapTileProvider(
      tileType: OpenWeatherMapTileType.precipitation,
    ),
    // * Apply opacity and adaptive smooth blending in tileBuilder
    // * OpenWeatherMap precipitation tiles show blue for rain, transparent for no rain
    // * Use adaptive blur - stronger blur at higher zoom levels to smooth scaled tiles
    tileBuilder: (context, tileWidget, tile) {
      final opacity = manager.getLayerConfig(WeatherLayerType.rain).opacity;
      // * Only apply opacity if > 0 to ensure tiles are visible
      if (opacity <= 0) {
        return const SizedBox.shrink();
      }
      // * Remove square artifacts by using extreme blur and removing ClipRect
      // * ClipRect creates hard edges - removing it allows blur to extend beyond tile boundaries
      // * This creates smooth, seamless blending between tiles like the original smooth appearance
      final zoom = tile.coordinates.z;
      // * Use extreme blur - stronger at lower zoom levels where squares are more visible
      // * Remove ClipRect to allow blur to blend across tile boundaries
      final blurSigma = zoom <= 7
          ? 12.0 - ((zoom - 2) * 0.6) // * 12.0 at zoom 2, down to 9.0 at zoom 7
          : zoom <= 10
              ? 9.0 - ((zoom - 7) * 0.67) // * 9.0 at zoom 7, down to 7.0 at zoom 10
              : 7.0; // * Minimum 7.0 blur at all higher zoom levels
      return Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: tileWidget,
        ),
      );
    },
  );
}

/// * OpenWeatherMap Tile Provider
/// * Provides tiles from OpenWeatherMap weather tile service
enum OpenWeatherMapTileType {
  precipitation,
  temperature,
  clouds,
}

class OpenWeatherMapTileProvider extends TileProvider {
  final OpenWeatherMapTileType tileType;
  
  OpenWeatherMapTileProvider({
    required this.tileType,
  });
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    String url;
    try {
      // * OpenWeatherMap only provides tiles up to zoom 10
      // * For higher zoom levels, use zoom 10 tiles and let flutter_map scale them
      final nativeZoom = coordinates.z.clamp(0, 10);
      
      // * When requesting tiles at zoom > 10, we need to get the parent tile at zoom 10
      // * Each zoom level doubles the number of tiles, so we divide by 2^(zoomDiff)
      int nativeX = coordinates.x;
      int nativeY = coordinates.y;
      
      if (coordinates.z > 10) {
        final zoomDiff = coordinates.z - 10;
        final divisor = 1 << zoomDiff; // * 2^zoomDiff
        nativeX = coordinates.x ~/ divisor;
        nativeY = coordinates.y ~/ divisor;
      }
      
      switch (tileType) {
        case OpenWeatherMapTileType.precipitation:
          url = WeatherConfig.getOpenWeatherMapRainTileUrl(
            nativeZoom,
            nativeX,
            nativeY,
          );
          break;
        case OpenWeatherMapTileType.temperature:
          url = WeatherConfig.getOpenWeatherMapTempTileUrl(
            nativeZoom,
            nativeX,
            nativeY,
          );
          break;
        case OpenWeatherMapTileType.clouds:
          url = WeatherConfig.getOpenWeatherMapCloudsTileUrl(
            nativeZoom,
            nativeX,
            nativeY,
          );
          break;
      }
      if (kDebugMode) {
        debugPrint("🌤️ [OpenWeatherMapTileProvider] Loading ${tileType.name} tile: requested z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}, native z=$nativeZoom, x=$nativeX, y=$nativeY");
        debugPrint("🌤️ [OpenWeatherMapTileProvider] URL: $url");
      }
    } catch (e) {
      debugPrint("❌ [OpenWeatherMapTileProvider] Error generating URL: $e");
      // * Return transparent placeholder on error
      return const NetworkImage("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");
    }
    return NetworkImage(url);
  }
}

/// * Heat Layer using OpenWeatherMap temperature tiles
/// * 
/// * OpenWeatherMap provides temperature visualization tiles
/// * URL format: https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}
/// * 
/// * Note: Temperature tiles may not be highly accurate as they use interpolated data.
/// * Consider this layer as a general temperature indicator rather than precise measurements.
class HeatLayer extends TileLayer {
  final WeatherLayerManager manager;
  
  HeatLayer({
    required this.manager,
  }) : super(
    urlTemplate: WeatherConfig.getOpenWeatherMapTempTileUrl(0, 0, 0), // * Will be replaced by tileProvider
    userAgentPackageName: "com.smartroad.app",
    maxZoom: 18, // * Match map maxZoom to keep layer visible at all zoom levels
    minZoom: 2,
    tileProvider: OpenWeatherMapTileProvider(
      tileType: OpenWeatherMapTileType.temperature,
    ),
    tileBuilder: (context, tileWidget, tile) {
      // * Apply opacity and adaptive smooth blending for heat layer
      // * OpenWeatherMap temperature tiles may not be highly accurate - use with caution
      // * Use lower opacity (max 0.5) to prevent solid color appearance
      // * Use adaptive blur - stronger at higher zoom levels
      final baseOpacity = manager.getLayerConfig(WeatherLayerType.heat).opacity;
      final adjustedOpacity = baseOpacity * 0.5; // * Reduced to 50% for better accuracy perception
      if (adjustedOpacity <= 0) {
        return const SizedBox.shrink();
      }
      // * Remove square artifacts by using extreme blur and removing ClipRect
      // * ClipRect creates hard edges - removing it allows blur to extend beyond tile boundaries
      final zoom = tile.coordinates.z;
      // * Use extreme blur - stronger at lower zoom levels
      final blurSigma = zoom <= 7
          ? 12.0 - ((zoom - 2) * 0.6) // * 12.0 at zoom 2, down to 9.0 at zoom 7
          : zoom <= 10
              ? 9.0 - ((zoom - 7) * 0.67) // * 9.0 at zoom 7, down to 7.0 at zoom 10
              : 7.0; // * Minimum 7.0 blur at all higher zoom levels
      return Opacity(
        opacity: adjustedOpacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: tileWidget,
        ),
      );
    },
  );
}

/// * Cloud Layer using OpenWeatherMap cloud coverage tiles
/// * 
/// * OpenWeatherMap provides cloud coverage visualization tiles
/// * URL format: https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid={apiKey}
class CloudLayer extends TileLayer {
  final WeatherLayerManager manager;
  
  CloudLayer({
    required this.manager,
  }) : super(
    urlTemplate: WeatherConfig.getOpenWeatherMapCloudsTileUrl(0, 0, 0), // * Will be replaced by tileProvider
    userAgentPackageName: "com.smartroad.app",
    maxZoom: 18, // * Match map maxZoom to keep layer visible at all zoom levels
    minZoom: 2,
    tileProvider: OpenWeatherMapTileProvider(
      tileType: OpenWeatherMapTileType.clouds,
    ),
    tileBuilder: (context, tileWidget, tile) {
      // * Apply opacity and adaptive smooth blending for cloud layer
      // * Use adaptive blur - stronger at higher zoom levels to smooth scaled tiles
      final opacity = manager.getLayerConfig(WeatherLayerType.clouds).opacity;
      if (opacity <= 0) {
        return const SizedBox.shrink();
      }
      // * Remove square artifacts by using extreme blur and removing ClipRect
      // * ClipRect creates hard edges - removing it allows blur to extend beyond tile boundaries
      final zoom = tile.coordinates.z;
      // * Use extreme blur - stronger at lower zoom levels
      final blurSigma = zoom <= 7
          ? 12.0 - ((zoom - 2) * 0.6) // * 12.0 at zoom 2, down to 9.0 at zoom 7
          : zoom <= 10
              ? 9.0 - ((zoom - 7) * 0.67) // * 9.0 at zoom 7, down to 7.0 at zoom 10
              : 7.0; // * Minimum 7.0 blur at all higher zoom levels
      return Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: tileWidget,
        ),
      );
    },
  );
}

/// * Weather Tile Layer Provider
/// * Custom tile provider for heat and cloud layers
/// * 
/// * Fetches real weather data from Open-Meteo and generates colored tiles
class WeatherTileProvider extends TileProvider {
  final WeatherLayerType layerType;
  final WeatherTileGenerator _tileGenerator = WeatherTileGenerator();
  
  WeatherTileProvider({
    required this.layerType,
  });
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // * Calculate tile bounds
    final nw = _tileToLatLng(coordinates.x.toDouble(), coordinates.y.toDouble(), coordinates.z);
    final se = _tileToLatLng((coordinates.x + 1).toDouble(), (coordinates.y + 1).toDouble(), coordinates.z);
    
    // * Generate tile based on layer type
    switch (layerType) {
      case WeatherLayerType.heat:
        return _generateHeatTileImage(nw, se, coordinates.z);
      case WeatherLayerType.clouds:
        return _generateCloudTileImage(nw, se, coordinates.z);
      case WeatherLayerType.rain:
        // * Rain uses OpenWeatherMap directly, shouldn't reach here
        return const NetworkImage("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==");
    }
  }
  
  /// * Generate heat tile image from temperature data
  ImageProvider _generateHeatTileImage(LatLng nw, LatLng se, int zoom) {
    // * Use async generator to fetch and create tile
    return _AsyncWeatherTileImage(
      generator: () => _tileGenerator.generateHeatTile(
        north: nw.latitude,
        south: se.latitude,
        east: se.longitude,
        west: nw.longitude,
        zoom: zoom,
      ),
    );
  }
  
  /// * Generate cloud tile image from cloud coverage data
  ImageProvider _generateCloudTileImage(LatLng nw, LatLng se, int zoom) {
    return _AsyncWeatherTileImage(
      generator: () => _tileGenerator.generateCloudTile(
        north: nw.latitude,
        south: se.latitude,
        east: se.longitude,
        west: nw.longitude,
        zoom: zoom,
      ),
    );
  }
  
  /// * Convert tile coordinates to LatLng
  LatLng _tileToLatLng(double x, double y, int z) {
    final n = math.pow(2.0, z);
    // * Calculate sinh manually: sinh(x) = (e^x - e^(-x)) / 2
    final expArg = math.pi * (1 - 2 * y / n);
    final sinhValue = (math.exp(expArg) - math.exp(-expArg)) / 2.0;
    final latRad = math.atan(sinhValue);
    final lat = latRad * 180.0 / math.pi;
    final lon = x / n * 360.0 - 180.0;
    return LatLng(lat, lon);
  }
}

/// * Async weather tile image provider
/// * Handles async tile generation from weather data
class _AsyncWeatherTileImage extends ImageProvider<_AsyncWeatherTileImage> {
  final Future<Uint8List?> Function() generator;
  
  const _AsyncWeatherTileImage({
    required this.generator,
  });
  
  @override
  Future<_AsyncWeatherTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }
  
  @override
  ImageStreamCompleter loadImage(_AsyncWeatherTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }
  
  Future<ui.Codec> _loadAsync(_AsyncWeatherTileImage key, ImageDecoderCallback decode) async {
    try {
      final bytes = await key.generator();
      if (bytes != null && bytes.isNotEmpty) {
        return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      }
    } catch (e) {
      debugPrint("❌ [_AsyncWeatherTileImage] Error loading tile: $e");
    }
    
    // * Return transparent placeholder if generation fails
    return decode(await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]),
    ));
  }
}
