/// * Weather Tile Generator
/// * Generates weather tiles from Open-Meteo API data
import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:typed_data";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "dart:ui" as ui;
import "../config/weather_config.dart";

/// * Weather tile generator service
class WeatherTileGenerator {
  static final WeatherTileGenerator _instance = WeatherTileGenerator._internal();
  factory WeatherTileGenerator() => _instance;
  WeatherTileGenerator._internal();
  
  // * Open-Meteo API endpoint
  static const String _apiUrl = "https://api.open-meteo.com/v1/forecast";
  
  // * Tile cache (key: "type_lat_lon_z", value: Uint8List PNG bytes)
  final Map<String, Uint8List> _tileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // * Rate limiting: Max concurrent requests, min delay between requests
  // * On web, use extremely conservative limits to avoid rate limit issues (429 errors)
  // * Open-Meteo has strict rate limits, especially for web clients
  int _activeRequests = 0;
  static int get _maxConcurrentRequests => kIsWeb ? 1 : 5; // * Only 1 concurrent request on web
  static Duration get _minRequestDelay => kIsWeb ? const Duration(milliseconds: 5000) : const Duration(milliseconds: 200); // * 5 second delay on web (extremely conservative)
  DateTime? _lastRequestTime;
  final Queue<Completer<void>> _requestQueue = Queue<Completer<void>>();
  
  // * Circuit breaker: Stop making requests after hitting rate limits
  DateTime? _circuitBreakerUntil;
  static Duration get _circuitBreakerDuration => kIsWeb ? const Duration(minutes: 2) : const Duration(seconds: 30); // * 2 minute cooldown on web after rate limit
  int _consecutiveRateLimitErrors = 0;
  static int get _maxConsecutiveRateLimitErrors => kIsWeb ? 2 : 5; // * After 2 rate limit errors on web, activate circuit breaker
  
  // * Retry configuration
  // * On web, use longer delays and fewer retries to avoid rate limits
  static int get _maxRetries => kIsWeb ? 0 : 3; // * No retries on web to avoid hitting rate limits
  static Duration get _initialRetryDelay => kIsWeb ? const Duration(seconds: 10) : const Duration(seconds: 1); // * 10 second delay on web if retry needed
  
  /// * Generate heat tile from temperature data
  /// * 
  /// * Fetches temperature data for multiple points across tile and generates gradient tile
  Future<Uint8List?> generateHeatTile({
    required double north,
    required double south,
    required double east,
    required double west,
    required int zoom,
  }) async {
    final cacheKey = "heat_${north.toStringAsFixed(4)}_${south.toStringAsFixed(4)}_${east.toStringAsFixed(4)}_${west.toStringAsFixed(4)}_$zoom";
    
    // * Check cache
    if (_tileCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheDuration) {
        return _tileCache[cacheKey];
      }
    }
    
    try {
      // * Sample multiple points across the tile (grid sampling)
      // * On web, use single point (1x1) to minimize API calls and avoid rate limits
      // * On other platforms, use 2x2 grid for smoother gradients
      final gridSize = kIsWeb ? 1 : 2;
      final latStep = gridSize > 1 ? (north - south) / (gridSize - 1) : 0.0;
      final lonStep = gridSize > 1 ? (east - west) / (gridSize - 1) : 0.0;
      
      // * Fetch temperatures sequentially with rate limiting
      final temperatureGrid = <List<double?>>[];
      for (int i = 0; i < gridSize; i++) {
        final row = <double?>[];
        for (int j = 0; j < gridSize; j++) {
          final lat = gridSize > 1 ? north - (i * latStep) : (north + south) / 2.0;
          final lon = gridSize > 1 ? west + (j * lonStep) : (east + west) / 2.0;
          
          // * Rate limit: wait if too many concurrent requests
          await _waitForRequestSlot();
          
          final temp = await _fetchTemperatureWithRetry(lat, lon);
          row.add(temp);
          
          // * Small delay between requests to avoid rate limits
          await Future.delayed(_minRequestDelay);
        }
        temperatureGrid.add(row);
      }
      
      // * Generate gradient tile with interpolation
      final tile = await _generateTemperatureTileWithGrid(temperatureGrid, zoom);
      
      // * Cache the tile
      if (tile != null) {
        _tileCache[cacheKey] = tile;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }
      
      return tile;
    } catch (e) {
      debugPrint("❌ [WeatherTileGenerator] Error generating heat tile: $e");
    }
    
    return null;
  }
  
  /// * Generate cloud tile from cloud coverage data
  /// * 
  /// * Fetches cloud coverage for multiple points and generates gradient tile
  Future<Uint8List?> generateCloudTile({
    required double north,
    required double south,
    required double east,
    required double west,
    required int zoom,
  }) async {
    final cacheKey = "cloud_${north.toStringAsFixed(4)}_${south.toStringAsFixed(4)}_${east.toStringAsFixed(4)}_${west.toStringAsFixed(4)}_$zoom";
    
    // * Check cache
    if (_tileCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheDuration) {
        return _tileCache[cacheKey];
      }
    }
    
    try {
      // * Sample multiple points across the tile (grid sampling)
      // * On web, use single point (1x1) to minimize API calls and avoid rate limits
      // * On other platforms, use 2x2 grid for smoother gradients
      final gridSize = kIsWeb ? 1 : 2;
      final latStep = gridSize > 1 ? (north - south) / (gridSize - 1) : 0.0;
      final lonStep = gridSize > 1 ? (east - west) / (gridSize - 1) : 0.0;
      
      // * Fetch cloud coverage sequentially with rate limiting
      final cloudGrid = <List<double?>>[];
      for (int i = 0; i < gridSize; i++) {
        final row = <double?>[];
        for (int j = 0; j < gridSize; j++) {
          final lat = gridSize > 1 ? north - (i * latStep) : (north + south) / 2.0;
          final lon = gridSize > 1 ? west + (j * lonStep) : (east + west) / 2.0;
          
          // * Rate limit: wait if too many concurrent requests
          await _waitForRequestSlot();
          
          final cloud = await _fetchCloudCoverWithRetry(lat, lon);
          row.add(cloud);
          
          // * Small delay between requests to avoid rate limits
          await Future.delayed(_minRequestDelay);
        }
        cloudGrid.add(row);
      }
      
      // * Generate gradient tile with interpolation
      final tile = await _generateCloudCoverageTileWithGrid(cloudGrid, zoom);
      
      if (tile != null) {
        _tileCache[cacheKey] = tile;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }
      
      return tile;
    } catch (e) {
      debugPrint("❌ [WeatherTileGenerator] Error generating cloud tile: $e");
    }
    
    return null;
  }
  
  /// * Generate temperature tile image with gradient interpolation
  /// * 
  /// * Uses efficient gradient rendering instead of pixel-by-pixel
  Future<Uint8List?> _generateTemperatureTileWithGrid(List<List<double?>> temperatureGrid, int zoom) async {
    try {
      const size = 256;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final gridSize = temperatureGrid.length;
      
      // * Handle single point (1x1 grid) - fill entire tile
      if (gridSize == 1 && temperatureGrid[0].isNotEmpty) {
        final temp = temperatureGrid[0][0];
        if (temp != null) {
          final color = _temperatureToColor(temp);
          final paint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
            paint,
          );
        }
      } else if (gridSize > 1) {
        // * Multi-point grid - render gradient rectangles
        final cellSize = size / (gridSize - 1);
        
        for (int i = 0; i < gridSize - 1; i++) {
          for (int j = 0; j < gridSize - 1; j++) {
            final x = j * cellSize;
            final y = i * cellSize;
            
            final v00 = temperatureGrid[i][j];
            final v01 = temperatureGrid[i][j + 1];
            final v10 = temperatureGrid[i + 1][j];
            final v11 = temperatureGrid[i + 1][j + 1];
            
            // * Skip if all values are null
            if (v00 == null && v01 == null && v10 == null && v11 == null) {
              continue;
            }
            
            // * Calculate average temperature for this cell
            final values = [v00, v01, v10, v11].whereType<double>().toList();
            if (values.isEmpty) continue;
            
            final avgTemp = values.reduce((a, b) => a + b) / values.length;
            final color = _temperatureToColor(avgTemp);
            
            // * Draw gradient rectangle
            final paint = Paint()
              ..color = color
              ..style = PaintingStyle.fill;
            
            canvas.drawRect(
              Rect.fromLTWH(x, y, cellSize, cellSize),
              paint,
            );
          }
        }
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("❌ [WeatherTileGenerator] Error creating temperature tile: $e");
      return null;
    }
  }
  
  /// * Convert temperature to color with opacity
  Color _temperatureToColor(double temperature) {
    Color baseColor;
    double opacity;
    
    if (temperature < 0) {
      baseColor = Colors.blue;
      opacity = 0.15;
    } else if (temperature < 15) {
      baseColor = Colors.cyan;
      opacity = 0.2;
    } else if (temperature < 25) {
      baseColor = Colors.green;
      opacity = 0.15;
    } else if (temperature < 30) {
      baseColor = Colors.yellow;
      opacity = 0.25;
    } else if (temperature < 35) {
      baseColor = Colors.orange;
      opacity = 0.35;
    } else {
      baseColor = Colors.red;
      opacity = 0.45;
    }
    
    return baseColor.withOpacity(opacity);
  }
  
  /// * Generate cloud coverage tile image with gradient interpolation
  /// * 
  /// * Uses efficient gradient rendering instead of pixel-by-pixel
  Future<Uint8List?> _generateCloudCoverageTileWithGrid(List<List<double?>> cloudGrid, int zoom) async {
    try {
      const size = 256;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final gridSize = cloudGrid.length;
      
      // * Handle single point (1x1 grid) - fill entire tile
      if (gridSize == 1 && cloudGrid[0].isNotEmpty) {
        final cloud = cloudGrid[0][0];
        if (cloud != null && cloud > 0) {
          final opacity = (cloud / 100.0).clamp(0.0, 1.0) * 0.4; // * Max 40% opacity
          if (opacity > 0.02) {
            final paint = Paint()
              ..color = Colors.grey.withOpacity(opacity)
              ..style = PaintingStyle.fill;
            canvas.drawRect(
              Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
              paint,
            );
          }
        }
      } else if (gridSize > 1) {
        // * Multi-point grid - render gradient rectangles
        final cellSize = size / (gridSize - 1);
        
        for (int i = 0; i < gridSize - 1; i++) {
          for (int j = 0; j < gridSize - 1; j++) {
            final x = j * cellSize;
            final y = i * cellSize;
            
            final v00 = cloudGrid[i][j];
            final v01 = cloudGrid[i][j + 1];
            final v10 = cloudGrid[i + 1][j];
            final v11 = cloudGrid[i + 1][j + 1];
            
            // * Skip if all values are null
            if (v00 == null && v01 == null && v10 == null && v11 == null) {
              continue;
            }
            
            // * Calculate average cloud coverage for this cell
            final values = [v00, v01, v10, v11].whereType<double>().toList();
            if (values.isEmpty) continue;
            
            final avgCloud = values.reduce((a, b) => a + b) / values.length;
            
            if (avgCloud > 0) {
              // * Map cloud coverage (0-100%) to opacity
              final opacity = (avgCloud / 100.0).clamp(0.0, 1.0) * 0.4; // * Max 40% opacity
              
              if (opacity > 0.02) {
                final paint = Paint()
                  ..color = Colors.grey.withOpacity(opacity)
                  ..style = PaintingStyle.fill;
                
                canvas.drawRect(
                  Rect.fromLTWH(x, y, cellSize, cellSize),
                  paint,
                );
              }
            }
          }
        }
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("❌ [WeatherTileGenerator] Error creating cloud tile: $e");
      return null;
    }
  }
  
  /// * Wait for available request slot (rate limiting)
  /// * 
  /// * Ensures only one request happens at a time on web, with strict delays
  /// * Includes circuit breaker to stop requests after hitting rate limits
  Future<void> _waitForRequestSlot() async {
    // * Check circuit breaker
    if (_circuitBreakerUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_circuitBreakerUntil!)) {
        final remaining = _circuitBreakerUntil!.difference(now);
        debugPrint("🚫 [WeatherTileGenerator] Circuit breaker active - waiting ${remaining.inSeconds}s before allowing requests");
        await Future.delayed(remaining);
        _circuitBreakerUntil = null; // * Reset after waiting
        _consecutiveRateLimitErrors = 0; // * Reset error count
      } else {
        _circuitBreakerUntil = null; // * Circuit breaker expired
        _consecutiveRateLimitErrors = 0; // * Reset error count
      }
    }
    
    // * Wait for available slot
    while (_activeRequests >= _maxConcurrentRequests) {
      final completer = Completer<void>();
      _requestQueue.add(completer);
      await completer.future;
    }
    
    // * Ensure minimum delay between requests (critical for avoiding 429 errors)
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestDelay) {
        final waitTime = _minRequestDelay - timeSinceLastRequest;
        if (kIsWeb) {
          debugPrint("⏳ [WeatherTileGenerator] Rate limiting: waiting ${waitTime.inMilliseconds}ms before next request");
        }
        await Future.delayed(waitTime);
      }
    }
    
    _activeRequests++;
    _lastRequestTime = DateTime.now();
  }
  
  /// * Release request slot
  void _releaseRequestSlot() {
    _activeRequests--;
    if (_requestQueue.isNotEmpty) {
      final completer = _requestQueue.removeFirst();
      completer.complete();
    }
  }
  
  /// * Fetch temperature with retry logic and exponential backoff
  /// * 
  /// * On web, retries are disabled to avoid hitting rate limits
  Future<double?> _fetchTemperatureWithRetry(double lat, double lon) async {
    try {
      // * On web, don't retry to avoid rate limits
      if (kIsWeb && _maxRetries == 0) {
        final result = await _fetchTemperature(lat, lon);
        return result;
      }
      
      // * On other platforms, retry with exponential backoff
      for (int attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          final result = await _fetchTemperature(lat, lon);
          return result;
        } catch (e) {
          if (attempt < _maxRetries) {
            // * Exponential backoff: 1s, 2s, 4s
            final delay = Duration(milliseconds: _initialRetryDelay.inMilliseconds * (1 << attempt));
            debugPrint("⚠️ [WeatherTileGenerator] Retry ${attempt + 1}/$_maxRetries for temperature after ${delay.inSeconds}s");
            await Future.delayed(delay);
          } else {
            debugPrint("❌ [WeatherTileGenerator] Failed to fetch temperature after ${_maxRetries + 1} attempts: $e");
          }
        }
      }
    } finally {
      _releaseRequestSlot();
    }
    return null;
  }
  
  /// * Fetch cloud coverage with retry logic and exponential backoff
  /// * 
  /// * On web, retries are disabled to avoid hitting rate limits
  Future<double?> _fetchCloudCoverWithRetry(double lat, double lon) async {
    try {
      // * On web, don't retry to avoid rate limits
      if (kIsWeb && _maxRetries == 0) {
        final result = await _fetchCloudCover(lat, lon);
        return result;
      }
      
      // * On other platforms, retry with exponential backoff
      for (int attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          final result = await _fetchCloudCover(lat, lon);
          return result;
        } catch (e) {
          if (attempt < _maxRetries) {
            // * Exponential backoff: 1s, 2s, 4s
            final delay = Duration(milliseconds: _initialRetryDelay.inMilliseconds * (1 << attempt));
            debugPrint("⚠️ [WeatherTileGenerator] Retry ${attempt + 1}/$_maxRetries for cloud cover after ${delay.inSeconds}s");
            await Future.delayed(delay);
          } else {
            debugPrint("❌ [WeatherTileGenerator] Failed to fetch cloud cover after ${_maxRetries + 1} attempts: $e");
          }
        }
      }
    } finally {
      _releaseRequestSlot();
    }
    return null;
  }
  
  /// * Fetch temperature for a single point
  Future<double?> _fetchTemperature(double lat, double lon) async {
    // * Use proxy if configured, otherwise use direct Open-Meteo URL
    final urlString = WeatherConfig.useProxy
      ? WeatherConfig.getOpenMeteoProxyUrl(lat, lon, "temperature_2m")
      : "$_apiUrl?latitude=$lat&longitude=$lon&current=temperature_2m";
    
    final url = Uri.parse(urlString);
    
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SmartRoad App'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // * Success - reset consecutive error count
        _consecutiveRateLimitErrors = 0;
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        return (current?['temperature_2m'] as num?)?.toDouble();
      } else if (response.statusCode == 429) {
        // * Rate limited - activate circuit breaker on web
        _consecutiveRateLimitErrors++;
        debugPrint("⚠️ [WeatherTileGenerator] Rate limited (429) for temperature at ($lat, $lon) - consecutive errors: $_consecutiveRateLimitErrors");
        
        if (kIsWeb && _consecutiveRateLimitErrors >= _maxConsecutiveRateLimitErrors) {
          // * Activate circuit breaker
          _circuitBreakerUntil = DateTime.now().add(_circuitBreakerDuration);
          debugPrint("🚫 [WeatherTileGenerator] Circuit breaker activated - stopping requests for ${_circuitBreakerDuration.inMinutes} minutes");
        }
        
        if (!kIsWeb) {
          throw Exception("Rate limited (429)");
        }
        return null;
      } else {
        debugPrint("⚠️ [WeatherTileGenerator] Temperature API error: ${response.statusCode} for ($lat, $lon)");
        return null;
      }
    } catch (e) {
      // * Re-throw to trigger retry logic
      if (e.toString().contains('429') || e.toString().contains('Rate limited')) {
        throw e;
      }
      debugPrint("❌ [WeatherTileGenerator] Error fetching temperature: $e");
      return null;
    }
  }
  
  /// * Fetch cloud coverage for a single point
  Future<double?> _fetchCloudCover(double lat, double lon) async {
    // * Use proxy if configured, otherwise use direct Open-Meteo URL
    final urlString = WeatherConfig.useProxy
      ? WeatherConfig.getOpenMeteoProxyUrl(lat, lon, "cloud_cover")
      : "$_apiUrl?latitude=$lat&longitude=$lon&current=cloud_cover";
    
    final url = Uri.parse(urlString);
    
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SmartRoad App'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // * Success - reset consecutive error count
        _consecutiveRateLimitErrors = 0;
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        return (current?['cloud_cover'] as num?)?.toDouble();
      } else if (response.statusCode == 429) {
        // * Rate limited - activate circuit breaker on web
        _consecutiveRateLimitErrors++;
        debugPrint("⚠️ [WeatherTileGenerator] Rate limited (429) for cloud cover at ($lat, $lon) - consecutive errors: $_consecutiveRateLimitErrors");
        
        if (kIsWeb && _consecutiveRateLimitErrors >= _maxConsecutiveRateLimitErrors) {
          // * Activate circuit breaker
          _circuitBreakerUntil = DateTime.now().add(_circuitBreakerDuration);
          debugPrint("🚫 [WeatherTileGenerator] Circuit breaker activated - stopping requests for ${_circuitBreakerDuration.inMinutes} minutes");
        }
        
        if (!kIsWeb) {
          throw Exception("Rate limited (429)");
        }
        return null;
      } else {
        debugPrint("⚠️ [WeatherTileGenerator] Cloud cover API error: ${response.statusCode} for ($lat, $lon)");
        return null;
      }
    } catch (e) {
      // * Re-throw to trigger retry logic
      if (e.toString().contains('429') || e.toString().contains('Rate limited')) {
        throw e;
      }
      debugPrint("❌ [WeatherTileGenerator] Error fetching cloud cover: $e");
      return null;
    }
  }
  
  /// * Clear cache
  void clearCache() {
    _tileCache.clear();
    _cacheTimestamps.clear();
  }
}

