/// * Weather Layer Manager
/// * Manages multiple weather tile layers (rain, heat, clouds)
/// * Provides tile URL generation and layer configuration
import "dart:async";
import "package:flutter/foundation.dart";

/// * Weather layer configuration
class WeatherLayerConfig {
  final bool enabled;
  final double opacity; // * 0.0 to 1.0
  
  WeatherLayerConfig({
    this.enabled = false,
    this.opacity = 0.5,
  });
  
  WeatherLayerConfig copyWith({
    bool? enabled,
    double? opacity,
  }) {
    return WeatherLayerConfig(
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// * Weather layer types
enum WeatherLayerType {
  rain,
  heat,
  clouds,
}

/// * Weather Layer Manager
/// * Manages all weather tile layers and their configurations
class WeatherLayerManager {
  static final WeatherLayerManager _instance = WeatherLayerManager._internal();
  factory WeatherLayerManager() => _instance;
  WeatherLayerManager._internal();
  
  // * Layer configurations
  final Map<WeatherLayerType, WeatherLayerConfig> _layers = {
    WeatherLayerType.rain: WeatherLayerConfig(),
    WeatherLayerType.heat: WeatherLayerConfig(),
    WeatherLayerType.clouds: WeatherLayerConfig(),
  };
  
  // * Rain animation frame (for RainViewer)
  int _rainFrame = 0;
  Timer? _rainAnimationTimer;
  
  // * Listeners for layer changes
  final List<VoidCallback> _listeners = [];
  
  // * Platform detection: RainViewer may have CORS issues on web, but we'll try anyway
  // * Note: CORS is a browser security restriction that cannot be bypassed from client-side code
  // * If CORS errors occur, the layer will fail gracefully
  bool get isRainLayerAvailable => true; // * Always available, but may fail on web due to CORS
  
  /// * Get layer configuration
  WeatherLayerConfig getLayerConfig(WeatherLayerType type) {
    return _layers[type] ?? WeatherLayerConfig();
  }
  
  /// * Set layer enabled state
  void setLayerEnabled(WeatherLayerType type, bool enabled) {
    // * Note: Rain layer may fail on web due to CORS, but we allow enabling it
    // * The layer will handle CORS errors gracefully
    
    final config = _layers[type];
    if (config != null && config.enabled != enabled) {
      _layers[type] = config.copyWith(enabled: enabled);
      _notifyListeners();
      
      // * Start/stop rain animation
      if (type == WeatherLayerType.rain) {
        if (enabled) {
          _startRainAnimation();
        } else {
          _stopRainAnimation();
        }
      }
    }
  }
  
  /// * Set layer opacity
  void setLayerOpacity(WeatherLayerType type, double opacity) {
    final config = _layers[type];
    if (config != null) {
      _layers[type] = config.copyWith(
        opacity: opacity.clamp(0.0, 1.0),
      );
      _notifyListeners();
    }
  }
  
  /// * Toggle layer
  void toggleLayer(WeatherLayerType type) {
    final config = _layers[type];
    if (config != null) {
      setLayerEnabled(type, !config.enabled);
    }
  }
  
  /// * Get rain animation frame (for RainViewer tiles)
  int getRainFrame() => _rainFrame;
  
  /// * Start rain animation timer
  void _startRainAnimation() {
    _stopRainAnimation();
    // * RainViewer updates every 10 minutes, cycle through frames
    _rainAnimationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _rainFrame = (_rainFrame + 1) % 6; // * 6 frames (past hour)
      _notifyListeners();
    });
  }
  
  /// * Stop rain animation timer
  void _stopRainAnimation() {
    _rainAnimationTimer?.cancel();
    _rainAnimationTimer = null;
    _rainFrame = 0;
  }
  
  /// * Add listener for layer changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  /// * Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  /// * Notify all listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint("❌ [WeatherLayerManager] Error in listener: $e");
      }
    }
  }
  
  /// * Dispose resources
  void dispose() {
    _stopRainAnimation();
    _listeners.clear();
  }
}

