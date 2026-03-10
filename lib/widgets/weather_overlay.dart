/// * Weather Overlay Widget
/// * Displays weather conditions as a semi-transparent overlay on the map
import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../core/theme/app_theme.dart";
import "../models/weather_state.dart";
import "../services/weather_service.dart";

/// * Weather overlay widget for map
class WeatherOverlay extends StatefulWidget {
  final LatLng center;
  final LatLngBounds? bounds;
  final bool isVisible;

  const WeatherOverlay({
    super.key,
    required this.center,
    this.bounds,
    this.isVisible = true,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  bool _isLoading = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _fetchWeather();
      // * Auto-update every 10-15 minutes
      _updateTimer = Timer.periodic(const Duration(minutes: 12), (_) {
        _fetchWeather();
      });
    }
  }

  @override
  void didUpdateWidget(WeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fetchWeather();
        _updateTimer = Timer.periodic(const Duration(minutes: 12), (_) {
          _fetchWeather();
        });
      } else {
        _updateTimer?.cancel();
        _updateTimer = null;
      }
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    if (!widget.isVisible || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final weatherData = await _weatherService.fetchWeatherData(
        center: widget.center,
        bounds: widget.bounds,
      );

      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _weatherData == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // * Semi-transparent color overlay
        Positioned.fill(child: Container(color: _weatherData!.overlayColor)),
        // * Weather icon at center
        Positioned(
          left: MediaQuery.of(context).size.width / 2 - 20,
          top: MediaQuery.of(context).size.height / 2 - 20,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _weatherData!.iconData,
              size: 24,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// * Weather overlay toggle button
class WeatherOverlayToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const WeatherOverlayToggle({
    super.key,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: onToggle,
      backgroundColor:
          isEnabled ? AppTheme.primaryColor : AppTheme.surfaceColor,
      child: Icon(
        isEnabled ? Icons.cloud : Icons.cloud_outlined,
        color: isEnabled ? Colors.white : AppTheme.textSecondary,
      ),
    );
  }
}

/// * Weather legend widget
class WeatherLegend extends StatelessWidget {
  const WeatherLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weather Conditions",
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _LegendItem(icon: "☀️", label: "Sunny"),
          _LegendItem(icon: "🔥", label: "Intense Heat"),
          _LegendItem(icon: "🌥️", label: "Cloudy"),
          _LegendItem(icon: "🌧️", label: "Light Rain"),
          _LegendItem(icon: "⛈️", label: "Heavy Rain"),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String icon;
  final String label;

  const _LegendItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppTheme.spacingMD),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
