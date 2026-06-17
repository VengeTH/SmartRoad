/// * Weather Feature Controller
/// *
/// * Manages weather data fetching and layer state for MapLibre.
/// * Integrates with Open-Meteo, RainViewer, and OpenWeatherMap.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../models/weather_state.dart';
import '../../services/weather_service.dart';
import '../../services/rainviewer_service.dart';
import '../../services/weather_layer_manager.dart';
import '../../config/weather_config.dart';

/// * Weather layer type for MapLibre rendering
enum MapLibreWeatherLayer { rain, clouds, temperature, none }

/// * Weather state for the feature controller
class WeatherFeatureState {
  bool rainEnabled = false;
  bool cloudsEnabled = false;
  bool temperatureEnabled = false;
  double rainOpacity = 0.5;
  double cloudsOpacity = 0.5;
  double temperatureOpacity = 0.4;
  WeatherData? currentConditions;
  bool isLoading = false;
  String? error;
}

/// * Callback for toggling weather layers on the map
typedef WeatherLayerToggleCallback =
    Future<void> Function(
      MapLibreWeatherLayer layer,
      bool enabled,
      double opacity,
    );

/// * Weather Feature Controller
class WeatherFeatureController {
  final WeatherService _weatherService = WeatherService();
  final RainViewerService _rainViewerService = RainViewerService();
  final WeatherLayerManager _layerManager = WeatherLayerManager();

  WeatherFeatureState _state = WeatherFeatureState();
  Timer? _refreshTimer;
  WeatherLayerToggleCallback? _onLayerToggle;

  WeatherFeatureState get state => _state;

  /// * Initialize the weather controller
  void initialize({WeatherLayerToggleCallback? onLayerToggle}) {
    _onLayerToggle = onLayerToggle;
    _layerManager.addListener(_onManagerChanged);
    // Refresh weather every 12 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 12), (_) {
      _refreshWeather();
    });
  }

  /// * Dispose
  void dispose() {
    _refreshTimer?.cancel();
    _layerManager.removeListener(_onManagerChanged);
  }

  void _onManagerChanged() {
    // Notify listeners (rebuild UI)
  }

  /// * Fetch current weather at a location
  Future<WeatherData?> fetchCurrentWeather(LatLng center) async {
    _state.isLoading = true;
    _state.error = null;

    try {
      final data = await _weatherService.fetchWeatherData(center: center);
      if (data != null) {
        _state.currentConditions = data;
      }
      _state.isLoading = false;
      return data;
    } catch (e) {
      _state.isLoading = false;
      _state.error = e.toString();
      return null;
    }
  }

  /// * Toggle rain layer
  Future<void> toggleRain(bool enabled) async {
    _state.rainEnabled = enabled;
    if (_onLayerToggle != null) {
      await _onLayerToggle!(
        MapLibreWeatherLayer.rain,
        enabled,
        _state.rainOpacity,
      );
    }
    _layerManager.setLayerEnabled(WeatherLayerType.rain, enabled);
  }

  /// * Toggle cloud layer
  Future<void> toggleClouds(bool enabled) async {
    _state.cloudsEnabled = enabled;
    if (_onLayerToggle != null) {
      await _onLayerToggle!(
        MapLibreWeatherLayer.clouds,
        enabled,
        _state.cloudsOpacity,
      );
    }
    _layerManager.setLayerEnabled(WeatherLayerType.clouds, enabled);
  }

  /// * Toggle temperature layer
  Future<void> toggleTemperature(bool enabled) async {
    _state.temperatureEnabled = enabled;
    if (_onLayerToggle != null) {
      await _onLayerToggle!(
        MapLibreWeatherLayer.temperature,
        enabled,
        _state.temperatureOpacity,
      );
    }
    _layerManager.setLayerEnabled(WeatherLayerType.heat, enabled);
  }

  /// * Set rain layer opacity
  Future<void> setRainOpacity(double opacity) async {
    _state.rainOpacity = opacity;
    if (_state.rainEnabled && _onLayerToggle != null) {
      await _onLayerToggle!(MapLibreWeatherLayer.rain, true, opacity);
    }
  }

  /// * Set cloud layer opacity
  Future<void> setCloudsOpacity(double opacity) async {
    _state.cloudsOpacity = opacity;
    if (_state.cloudsEnabled && _onLayerToggle != null) {
      await _onLayerToggle!(MapLibreWeatherLayer.clouds, true, opacity);
    }
  }

  /// * Set temperature layer opacity
  Future<void> setTemperatureOpacity(double opacity) async {
    _state.temperatureOpacity = opacity;
    if (_state.temperatureEnabled && _onLayerToggle != null) {
      await _onLayerToggle!(MapLibreWeatherLayer.temperature, true, opacity);
    }
  }

  /// * Get the appropriate rain tile URL
  String? get rainTileUrl {
    if (WeatherConfig.hasOpenWeatherMapKey) {
      return "https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid=${WeatherConfig.openWeatherMapApiKey}";
    }
    return null; // Will try RainViewer fallback
  }

  /// * Get the appropriate cloud tile URL
  String? get cloudTileUrl {
    if (WeatherConfig.hasOpenWeatherMapKey) {
      return "https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=${WeatherConfig.openWeatherMapApiKey}";
    }
    return null;
  }

  /// * Get the appropriate temperature tile URL
  String? get temperatureTileUrl {
    if (WeatherConfig.hasOpenWeatherMapKey) {
      return "https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid=${WeatherConfig.openWeatherMapApiKey}";
    }
    return null;
  }

  /// * Refresh weather data
  void _refreshWeather() {
    // Trigger weather refresh if needed
  }

  /// * Check weather alerts along a route
  Future<bool> checkRouteWeatherAlerts(List<LatLng> route) async {
    if (route.isEmpty) return false;
    // Sample weather at midpoint of route
    final midIndex = route.length ~/ 2;
    final midPoint = route[midIndex];
    final data = await fetchCurrentWeather(midPoint);
    if (data == null) return false;

    // Alert on heavy precipitation or storms
    return data.state == WeatherState.heavyRain ||
        data.state == WeatherState.lightRain;
  }
}
