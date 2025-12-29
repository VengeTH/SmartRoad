/// * Weather Tile Layers
/// * Raster tile layer implementations for weather visualization
import "dart:math" as math;
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_map/flutter_map.dart";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";
import "../services/weather_layer_manager.dart";
import "../services/weather_tile_generator.dart";
import "../services/rainviewer_service.dart";
import "../config/weather_config.dart";

/// * Rain Layer using RainViewer tiles
/// * 
/// * RainViewer provides real-time precipitation radar tiles
/// * URL format: https://tilecache.rainviewer.com/v2/radar/{timestamp}/{z}/{x}/{y}/2/{color}/{smooth}_{snow}.png
class RainLayer extends TileLayer {
  final WeatherLayerManager manager;
  final int frame; // * Animation frame (0 = most recent, higher = older)
  
  RainLayer({
    required this.manager,
    this.frame = 0,
  }) : super(
    urlTemplate: "https://tilecache.rainviewer.com/v2/radar/{timestamp}/{z}/{x}/{y}/2/1_1.png",
    userAgentPackageName: "com.smartroad.app",
    maxZoom: 10, // * RainViewer tiles available up to zoom 10
    minZoom: 2,
    tileProvider: RainViewerTileProvider(frame: frame),
    // * Apply opacity in tileBuilder
    tileBuilder: (context, tileWidget, tile) {
      return Opacity(
        opacity: manager.getLayerConfig(WeatherLayerType.rain).opacity,
        child: tileWidget,
      );
    },
  );
  
  /// * Create updated layer with new frame
  RainLayer copyWithFrame(int newFrame) {
    return RainLayer(
      manager: manager,
      frame: newFrame,
    );
  }
}

/// * RainViewer Tile Provider
/// * Fetches real timestamps from RainViewer API and builds correct tile URLs
class RainViewerTileProvider extends TileProvider {
  final int frame;
  final RainViewerService _rainViewerService = RainViewerService();
  
  RainViewerTileProvider({
    required this.frame,
  });
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // * Build URL with actual timestamp from RainViewer API
    return _RainViewerImageProvider(
      coordinates: coordinates,
      frame: frame,
      rainViewerService: _rainViewerService,
    );
  }
}

/// * RainViewer Image Provider
/// * Handles async timestamp fetching and tile URL building
class _RainViewerImageProvider extends ImageProvider<_RainViewerImageProvider> {
  final TileCoordinates coordinates;
  final int frame;
  final RainViewerService rainViewerService;
  
  const _RainViewerImageProvider({
    required this.coordinates,
    required this.frame,
    required this.rainViewerService,
  });
  
  @override
  Future<_RainViewerImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }
  
  @override
  ImageStreamCompleter loadImage(_RainViewerImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }
  
  Future<ui.Codec> _loadAsync(_RainViewerImageProvider key, ImageDecoderCallback decode) async {
    // * Try to load RainViewer tiles on all platforms
    // * Note: On web, CORS may block these requests, but we'll try anyway
    // * If CORS errors occur, they will be caught and handled gracefully
    const maxRetries = kIsWeb ? 2 : 3; // * Fewer retries on web due to CORS
    const initialRetryDelay = Duration(seconds: 1);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // * Get timestamp for the requested frame
        final timestamp = await key.rainViewerService.getTimestampForFrame(key.frame);
        
        if (timestamp == null) {
          debugPrint("⚠️ [_RainViewerImageProvider] No timestamp available for frame ${key.frame}");
          break;
        }
        
        // * Build RainViewer tile URL
        // * Use proxy if configured, otherwise use direct RainViewer URL
        final url = WeatherConfig.useProxy
          ? WeatherConfig.getRainViewerProxyUrl(
              timestamp,
              key.coordinates.z,
              key.coordinates.x,
              key.coordinates.y,
            )
          : "https://tilecache.rainviewer.com/v2/radar/$timestamp/${key.coordinates.z}/${key.coordinates.x}/${key.coordinates.y}/2/1_1.png";
        
        if (attempt == 0) {
          debugPrint("🌧️ [_RainViewerImageProvider] Loading tile: $url");
        }
        
        // * Fetch tile image with retry
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'SmartRoad App',
            'Referer': 'https://www.rainviewer.com/',
            'Accept': 'image/png,image/*;q=0.8',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          if (attempt > 0) {
            debugPrint("✅ [_RainViewerImageProvider] Successfully loaded rain tile after ${attempt + 1} attempts");
          }
          return decode(await ui.ImmutableBuffer.fromUint8List(response.bodyBytes));
        } else if (response.statusCode == 429) {
          // * Rate limited - retry with exponential backoff
          if (attempt < maxRetries - 1) {
            final delay = Duration(milliseconds: initialRetryDelay.inMilliseconds * (1 << attempt));
            debugPrint("⚠️ [_RainViewerImageProvider] Rate limited (429), retrying after ${delay.inSeconds}s");
            await Future.delayed(delay);
            continue;
          }
        } else {
          debugPrint("❌ [_RainViewerImageProvider] Failed to load tile: ${response.statusCode}, body length: ${response.bodyBytes.length}");
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: initialRetryDelay.inMilliseconds * (1 << attempt)));
            continue;
          }
        }
      } catch (e) {
        // * Check if it's a CORS error (common on web)
        final errorString = e.toString().toLowerCase();
        final isCorsError = errorString.contains('cors') || 
                           errorString.contains('access-control') || 
                           (errorString.contains('failed to fetch') && kIsWeb);
        
        if (isCorsError && kIsWeb) {
          // * On web, CORS errors are fatal - RainViewer doesn't send CORS headers
          // * This requires a backend proxy or CORS proxy to work on web
          if (attempt == 0) {
            debugPrint("⚠️ [_RainViewerImageProvider] CORS error on web - RainViewer tiles blocked by browser security policy");
            debugPrint("💡 [_RainViewerImageProvider] To enable rain on web, use a CORS proxy or backend proxy server");
          }
          // * Don't retry CORS errors on web
          break;
        } else if (isCorsError && !kIsWeb) {
          debugPrint("⚠️ [_RainViewerImageProvider] Network error (possibly CORS): $e");
        }
        
        // * Retry non-CORS errors
        if (attempt < maxRetries - 1 && !isCorsError) {
          final delay = Duration(milliseconds: initialRetryDelay.inMilliseconds * (1 << attempt));
          debugPrint("⚠️ [_RainViewerImageProvider] Error loading tile (attempt ${attempt + 1}/$maxRetries), retrying after ${delay.inSeconds}s: $e");
          await Future.delayed(delay);
        } else if (!isCorsError) {
          debugPrint("❌ [_RainViewerImageProvider] Error loading tile after $maxRetries attempts: $e");
        }
      }
    }
    
    // * Return transparent placeholder if fetch fails
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

/// * Heat Layer using temperature visualization
/// * 
/// * Uses Open-Meteo grid data converted to tile visualization
/// * For MVP, uses a gradient overlay approach
/// * FUTURE: Integrate with tile server that generates tiles from Open-Meteo data
class HeatLayer extends TileLayer {
  final WeatherLayerManager manager;
  
  HeatLayer({
    required this.manager,
  }) : super(
    // * For MVP: Use a placeholder URL pattern
    // * In production: Use tile server URL like "https://tiles.example.com/heat/{z}/{x}/{y}.png"
    urlTemplate: "https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m",
    userAgentPackageName: "com.smartroad.app",
    maxZoom: kIsWeb ? 7 : 12, // * Lower max zoom on web to reduce tile requests
    minZoom: 3,
    // * Use custom provider for heat tiles
    tileProvider: WeatherTileProvider(
      layerType: WeatherLayerType.heat,
    ),
    tileBuilder: (context, tileWidget, tile) {
      // * Apply opacity (tile already has color from weather data)
      return Opacity(
        opacity: manager.getLayerConfig(WeatherLayerType.heat).opacity,
        child: tileWidget,
      );
    },
  );
}

/// * Cloud Layer using cloud coverage visualization
/// * 
/// * Uses Open-Meteo cloud coverage data
/// * FUTURE: Integrate with tile server for better performance
class CloudLayer extends TileLayer {
  final WeatherLayerManager manager;
  
  CloudLayer({
    required this.manager,
  }) : super(
    urlTemplate: "https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=cloud_cover",
    userAgentPackageName: "com.smartroad.app",
    maxZoom: kIsWeb ? 7 : 12, // * Lower max zoom on web to reduce tile requests
    minZoom: 3,
    tileProvider: WeatherTileProvider(
      layerType: WeatherLayerType.clouds,
    ),
    tileBuilder: (context, tileWidget, tile) {
      // * Apply opacity (tile already has color from weather data)
      return Opacity(
        opacity: manager.getLayerConfig(WeatherLayerType.clouds).opacity,
        child: tileWidget,
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
        // * Rain uses RainViewer directly, shouldn't reach here
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
