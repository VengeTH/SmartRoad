/// * Weather Service
/// * Fetches weather data from Open-Meteo API for map overlay
/// * 
/// * FUTURE (Post-MVP): Weather-aware rerouting logic
/// * FUTURE (Post-MVP): Block roads based on weather conditions
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";
import "../models/weather_state.dart";

/// * Weather service for fetching weather data
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();
  
  // * Open-Meteo API endpoint (free, no API key required)
  static const String _apiUrl = "https://api.open-meteo.com/v1/forecast";
  
  /// * Cache for weather data (key: "lat_lon", value: WeatherData)
  final Map<String, WeatherData> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 10);
  
  /// * Fetch weather data for a region
  /// * 
  /// * [center] - Center point of the region
  /// * [bounds] - Bounding box for the region (optional, uses center if not provided)
  Future<WeatherData?> fetchWeatherData({
    required LatLng center,
    dynamic bounds, // * LatLngBounds from flutter_map (optional)
  }) async {
    try {
      // * Check cache first
      final cacheKey = "${center.latitude.toStringAsFixed(2)}_${center.longitude.toStringAsFixed(2)}";
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey]!;
        final age = DateTime.now().difference(cached.timestamp);
        if (age < _cacheDuration) {
          debugPrint("🌤️ [WeatherService] Using cached weather data");
          return cached;
        }
      }
      
      // * Fetch from API
      final url = Uri.parse(
        "$_apiUrl"
        "?latitude=${center.latitude}"
        "&longitude=${center.longitude}"
        "&current=temperature_2m,precipitation,weather_code"
        "&timezone=Asia/Manila"
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SmartRoad App',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        
        if (current == null) {
          return null;
        }
        
        final temperature = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
        final precipitation = (current['precipitation'] as num?)?.toDouble();
        final weatherCode = (current['weather_code'] as int?) ?? 0;
        
        // * Map weather code to WeatherState
        final state = _mapWeatherCodeToState(weatherCode, temperature, precipitation);
        
        final weatherData = WeatherData(
          state: state,
          temperature: temperature,
          precipitation: precipitation,
          latitude: center.latitude,
          longitude: center.longitude,
          timestamp: DateTime.now(),
        );
        
        // * Cache the result
        _cache[cacheKey] = weatherData;
        
        debugPrint("🌤️ [WeatherService] Fetched weather: ${weatherData.displayName} at ${temperature}°C");
        return weatherData;
      } else {
        debugPrint("❌ [WeatherService] API error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ [WeatherService] Error fetching weather: $e");
      return null;
    }
  }
  
  /// * Map Open-Meteo weather code to WeatherState
  /// * 
  /// * Weather codes: https://open-meteo.com/en/docs
  WeatherState _mapWeatherCodeToState(int code, double temperature, double? precipitation) {
    // * Check for intense heat (temperature > 35°C)
    if (temperature > 35.0) {
      return WeatherState.intenseHeat;
    }
    
    // * Check precipitation first
    if (precipitation != null && precipitation > 0) {
      if (precipitation > 2.5) {
        return WeatherState.heavyRain;
      } else {
        return WeatherState.lightRain;
      }
    }
    
    // * Map weather codes
    // * 0 = Clear sky
    // * 1-3 = Mainly clear, partly cloudy, overcast
    // * 45-48 = Fog
    // * 51-67 = Drizzle/Rain
    // * 71-77 = Snow
    // * 80-99 = Rain showers/Thunderstorm
    
    if (code == 0) {
      return WeatherState.sunny;
    } else if (code >= 1 && code <= 3) {
      return WeatherState.cloudy;
    } else if (code >= 45 && code <= 48) {
      return WeatherState.cloudy;
    } else if (code >= 51 && code <= 67) {
      return WeatherState.lightRain;
    } else if (code >= 80 && code <= 99) {
      return WeatherState.heavyRain;
    } else {
      // * Default to cloudy for unknown codes
      return WeatherState.cloudy;
    }
  }
  
  /// * Clear cache
  void clearCache() {
    _cache.clear();
  }
  
  /// * Get cached weather data
  WeatherData? getCachedWeather(LatLng center) {
    final cacheKey = "${center.latitude.toStringAsFixed(2)}_${center.longitude.toStringAsFixed(2)}";
    return _cache[cacheKey];
  }
}

