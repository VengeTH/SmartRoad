/// * Weather Configuration
/// * Configuration for weather layer proxy settings and API keys
import "package:flutter/foundation.dart";
import "../services/weather_layer_manager.dart";

/// * Weather proxy configuration
/// * 
/// * To enable weather layers on web, set up a backend proxy server
/// * and configure the proxy URL using environment variables or build flags.
/// * 
/// * For OpenWeatherMap, get a free API key from: https://openweathermap.org/api
/// * Free tier: 1,000 calls/day, 60 calls/minute
/// * 
/// * Example:
/// * ```bash
/// * flutter run --dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather --dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here
/// * ```
/// * 
/// * Or set in your IDE run configuration:
/// * - Android Studio: Run > Edit Configurations > Additional run args: `--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather --dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here`
/// * - VS Code: launch.json > args: `["--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather", "--dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here"]`
class WeatherConfig {
  /// * Backend proxy base URL
  /// * 
  /// * Set via environment variable: `--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather`
  /// * If not set, defaults to empty string (proxy disabled)
  static const String proxyBaseUrl = String.fromEnvironment(
    'WEATHER_PROXY_URL',
    defaultValue: '',
  );
  
  /// * OpenWeatherMap API key
  /// * 
  /// * Get your free API key from: https://openweathermap.org/api
  /// * Free tier: 1,000 calls/day, 60 calls/minute
  /// * 
  /// * Set via environment variable: `--dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here`
  /// * Example: flutter run --dart-define=OPENWEATHERMAP_API_KEY=
  static const String openWeatherMapApiKey = String.fromEnvironment(
    'OPENWEATHERMAP_API_KEY',
    defaultValue: '',
  );
  
  /// * Whether to use backend proxy
  /// * 
  /// * Returns true if proxyBaseUrl is not empty
  static bool get useProxy => proxyBaseUrl.isNotEmpty;
  
  /// * Whether OpenWeatherMap API key is configured
  static bool _hasLoggedKey = false;
  static bool get hasOpenWeatherMapKey {
    final hasKey = openWeatherMapApiKey.isNotEmpty;
    // * Only log once to prevent console overflow
    if (kDebugMode && !_hasLoggedKey) {
      final keyPreview = hasKey ? "${openWeatherMapApiKey.substring(0, 8)}..." : "not set";
      debugPrint("🔍 [WeatherConfig] OpenWeatherMap API Key: $keyPreview");
      _hasLoggedKey = true;
    }
    if (kDebugMode && !hasKey && kIsWeb) {
      debugPrint("⚠️ [WeatherConfig] OPENWEATHERMAP_API_KEY not set. Weather layers will not work on web.");
      debugPrint("💡 [WeatherConfig] Run with: flutter run --dart-define=OPENWEATHERMAP_API_KEY=your_api_key");
      debugPrint("💡 [WeatherConfig] Or use: .\\run.bat (Windows) or ./run-with-env.sh (Linux/Mac)");
    }
    return hasKey;
  }
  
  /// * Whether weather layers are available on current platform
  /// * 
  /// * On web: Available if API key OR proxy is configured
  /// * On other platforms: Always available
  static bool get areLayersAvailable {
    if (kIsWeb) {
      // * On web, need either API key (direct access) or proxy
      return hasOpenWeatherMapKey || useProxy;
    }
    return true;
  }
  
  /// * Get OpenWeatherMap tile URL for precipitation/rain
  /// * 
  /// * Format: https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={apiKey}
  static String getOpenWeatherMapRainTileUrl(int z, int x, int y) {
    if (useProxy) {
      return "$proxyBaseUrl/openweathermap/precipitation/$z/$x/$y";
    }
    if (!hasOpenWeatherMapKey) {
      throw StateError("OpenWeatherMap API key not configured. Set OPENWEATHERMAP_API_KEY environment variable.");
    }
    return "https://tile.openweathermap.org/map/precipitation_new/$z/$x/$y.png?appid=$openWeatherMapApiKey";
  }
  
  /// * Get OpenWeatherMap tile URL for temperature
  /// * 
  /// * Format: https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}
  static String getOpenWeatherMapTempTileUrl(int z, int x, int y) {
    if (useProxy) {
      return "$proxyBaseUrl/openweathermap/temperature/$z/$x/$y";
    }
    if (!hasOpenWeatherMapKey) {
      throw StateError("OpenWeatherMap API key not configured. Set OPENWEATHERMAP_API_KEY environment variable.");
    }
    return "https://tile.openweathermap.org/map/temp_new/$z/$x/$y.png?appid=$openWeatherMapApiKey";
  }
  
  /// * Get OpenWeatherMap tile URL for clouds
  /// * 
  /// * Format: https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid={apiKey}
  static String getOpenWeatherMapCloudsTileUrl(int z, int x, int y) {
    if (useProxy) {
      return "$proxyBaseUrl/openweathermap/clouds/$z/$x/$y";
    }
    if (!hasOpenWeatherMapKey) {
      throw StateError("OpenWeatherMap API key not configured. Set OPENWEATHERMAP_API_KEY environment variable.");
    }
    return "https://tile.openweathermap.org/map/clouds_new/$z/$x/$y.png?appid=$openWeatherMapApiKey";
  }
  
  /// * Get proxy URL for Open-Meteo forecast
  /// * 
  /// * Format: {proxyBaseUrl}/open-meteo/forecast?latitude={lat}&longitude={lon}&current={params}
  static String getOpenMeteoProxyUrl(double lat, double lon, String currentParams) {
    return "$proxyBaseUrl/open-meteo/forecast?latitude=$lat&longitude=$lon&current=$currentParams";
  }
  
  /// * Check if a layer is available on web
  /// * 
  /// * OpenWeatherMap requires either:
  /// * - API key configured (direct access)
  /// * - Proxy configured (proxy handles API key)
  static bool isLayerAvailableOnWeb(WeatherLayerType type) {
    if (!kIsWeb) return true; // Always available on non-web platforms
    
    // On web, need either API key or proxy
    return hasOpenWeatherMapKey || useProxy;
  }
}

