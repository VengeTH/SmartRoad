/// * Weather State Model
/// * Represents weather conditions for map overlay
import "package:flutter/material.dart";

enum WeatherState {
  sunny,        // * ☀️ Normal conditions
  intenseHeat,  // * 🔥 High temperature
  cloudy,       // * 🌥️ Cloudy skies
  lightRain,    // * 🌧️ Light precipitation
  heavyRain,    // * ⛈️ Heavy precipitation/storms
}

/// * Weather data for a region
class WeatherData {
  final WeatherState state;
  final double temperature; // * Celsius
  final double? precipitation; // * mm/h (null if no rain)
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  
  WeatherData({
    required this.state,
    required this.temperature,
    this.precipitation,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
  
  /// * Get icon data for weather state
  IconData get iconData {
    switch (state) {
      case WeatherState.sunny:
        return Icons.wb_sunny;
      case WeatherState.intenseHeat:
        return Icons.local_fire_department;
      case WeatherState.cloudy:
        return Icons.cloud;
      case WeatherState.lightRain:
        return Icons.umbrella; // Or water_drop
      case WeatherState.heavyRain:
        return Icons.thunderstorm;
    }
  }
  
  /// * Get color for weather overlay
  Color get overlayColor {
    switch (state) {
      case WeatherState.sunny:
        return Colors.yellow.withOpacity(0.1);
      case WeatherState.intenseHeat:
        return Colors.orange.withOpacity(0.2);
      case WeatherState.cloudy:
        return Colors.grey.withOpacity(0.15);
      case WeatherState.lightRain:
        return Colors.blue.withOpacity(0.2);
      case WeatherState.heavyRain:
        return Colors.blue.withOpacity(0.3);
    }
  }
  
  /// * Get display name
  String get displayName {
    switch (state) {
      case WeatherState.sunny:
        return "Sunny";
      case WeatherState.intenseHeat:
        return "Intense Heat";
      case WeatherState.cloudy:
        return "Cloudy";
      case WeatherState.lightRain:
        return "Light Rain";
      case WeatherState.heavyRain:
        return "Heavy Rain";
    }
  }
}

