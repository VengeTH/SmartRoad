/// * Weather Configuration
/// * Configuration for weather layer proxy settings
import "package:flutter/foundation.dart";

/// * Weather proxy configuration
/// * 
/// * To enable weather layers on web, set up a backend proxy server
/// * and configure the proxy URL using environment variables or build flags.
/// * 
/// * Example:
/// * ```bash
/// * flutter run --dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather
/// * ```
/// * 
/// * Or set in your IDE run configuration:
/// * - Android Studio: Run > Edit Configurations > Additional run args: `--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather`
/// * - VS Code: launch.json > args: `["--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather"]`
class WeatherConfig {
  /// * Backend proxy base URL
  /// * 
  /// * Set via environment variable: `--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather`
  /// * If not set, defaults to empty string (proxy disabled)
  static const String proxyBaseUrl = String.fromEnvironment(
    'WEATHER_PROXY_URL',
    defaultValue: '',
  );
  
  /// * Whether to use backend proxy
  /// * 
  /// * Returns true if proxyBaseUrl is not empty
  static bool get useProxy => proxyBaseUrl.isNotEmpty;
  
  /// * Whether weather layers are available on current platform
  /// * 
  /// * On web: Only available if proxy is configured
  /// * On other platforms: Always available
  static bool get areLayersAvailable {
    if (kIsWeb) {
      return useProxy;
    }
    return true;
  }
  
  /// * Get proxy URL for RainViewer tiles
  /// * 
  /// * Format: {proxyBaseUrl}/rainviewer/{timestamp}/{z}/{x}/{y}
  static String getRainViewerProxyUrl(int timestamp, int z, int x, int y) {
    return "$proxyBaseUrl/rainviewer/$timestamp/$z/$x/$y";
  }
  
  /// * Get proxy URL for Open-Meteo forecast
  /// * 
  /// * Format: {proxyBaseUrl}/open-meteo/forecast?latitude={lat}&longitude={lon}&current={params}
  static String getOpenMeteoProxyUrl(double lat, double lon, String currentParams) {
    return "$proxyBaseUrl/open-meteo/forecast?latitude=$lat&longitude=$lon&current=$currentParams";
  }
}

