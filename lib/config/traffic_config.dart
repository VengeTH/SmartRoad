/// * Traffic configuration
/// * 
/// * Using TomTom Traffic Flow tiles (free tier available)
/// * Documentation: https://developer.tomtom.com/traffic-api/documentation/product-information/introduction
/// * 
/// * Free tier: 2,500 requests/day
/// * Get free API key: https://developer.tomtom.com/
/// * 
/// * IMPORTANT: Ensure your API key has "Traffic API" service enabled in TomTom Developer Portal
/// * If you see 400 errors, check that Traffic API is enabled for your key
/// * 
/// * Traffic flow visualization:
/// * - Green: Free flow (fast)
/// * - Yellow: Moderate traffic
/// * - Red: Heavy traffic / Slow
/// * - Dark red: Very slow / Standstill
class TrafficConfig {
  /// * TomTom Traffic Flow tile base URL
  /// * 
  /// * Format: https://api.tomtom.com/traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?key={apiKey}
  /// * 
  /// * Documentation: https://developer.tomtom.com/traffic-api/traffic-flow/flow-tiles
  /// * Note: Requires API key from TomTom Developer Portal
  /// * IMPORTANT: Coordinates must be integers (z, x, y in that order)
  static const String _baseUrl = "https://api.tomtom.com/traffic/map/4/tile/flow/relative";
  
  /// * Get TomTom API key from environment
  /// * Set via --dart-define=TOMTOM_API_KEY=your_key
  static String get tomtomApiKey {
    return const String.fromEnvironment("TOMTOM_API_KEY", defaultValue: "");
  }
  
  /// * Get traffic tile URL
  /// * 
  /// * Returns URL for TomTom traffic flow tile
  /// * Returns transparent placeholder if API key is not set
  /// * 
  /// * Parameters must be integers (z, x, y in that order)
  /// * Format: /traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?key={apiKey}
  static String getTrafficTileUrl(int z, int x, int y) {
    final apiKey = tomtomApiKey;
    // * Ensure coordinates are integers (z, x, y in that order)
    // * Format: /traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?key={apiKey}
    final zInt = z.toInt();
    final xInt = x.toInt();
    final yInt = y.toInt();
    // * Return a valid URL even if key is empty; callers should gate requests via [isAvailable].
    return "$_baseUrl/$zInt/$xInt/$yInt.png?key=$apiKey";
  }
  
  /// * Check if traffic layer is available
  /// * 
  /// * Traffic tiles are available if API key is set
  static bool get isAvailable => tomtomApiKey.isNotEmpty;
}


