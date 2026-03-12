/// * Weather Layer Controls
/// * UI controls for toggling weather layers and adjusting opacity
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter/foundation.dart";
import "../core/theme/app_theme.dart";
import "../services/weather_layer_manager.dart";
import "../config/weather_config.dart";

/// * Weather layer control panel
class WeatherLayerControls extends StatefulWidget {
  final WeatherLayerManager manager;
  final VoidCallback? onLayersChanged;
  
  const WeatherLayerControls({
    super.key,
    required this.manager,
    this.onLayersChanged,
  });
  
  @override
  State<WeatherLayerControls> createState() => _WeatherLayerControlsState();
}

class _WeatherLayerControlsState extends State<WeatherLayerControls> {
  late WeatherLayerManager _manager;
  
  @override
  void initState() {
    super.initState();
    _manager = widget.manager;
    _manager.addListener(_onLayerChanged);
  }
  
  @override
  void dispose() {
    _manager.removeListener(_onLayerChanged);
    super.dispose();
  }
  
  void _onLayerChanged() {
    setState(() {});
    widget.onLayersChanged?.call();
  }
  
  @override
  Widget build(BuildContext context) {
    // * Debug: Log API key status
    if (kDebugMode && kIsWeb) {
      debugPrint("🔍 [WeatherLayerControls] API Key configured: ${WeatherConfig.hasOpenWeatherMapKey}");
      debugPrint("🔍 [WeatherLayerControls] Proxy configured: ${WeatherConfig.useProxy}");
      debugPrint("🔍 [WeatherLayerControls] Layers available: ${WeatherConfig.areLayersAvailable}");
    }
    
    // * Get screen width to constrain the panel
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 400.0 : screenWidth - (AppTheme.spacingMD * 4);
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.5,
        ),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers,
                size: 20,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                "Weather Layers",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _LayerControl(
            title: "Rain",
            icon: Icons.water_drop,
            iconColor: Colors.blue,
            enabled: _manager.getLayerConfig(WeatherLayerType.rain).enabled,
            opacity: _manager.getLayerConfig(WeatherLayerType.rain).opacity,
            available: WeatherConfig.isLayerAvailableOnWeb(WeatherLayerType.rain),
            unavailableMessage: !WeatherConfig.isLayerAvailableOnWeb(WeatherLayerType.rain)
              ? (kIsWeb ? "Requires API key or backend proxy. Set OPENWEATHERMAP_API_KEY or WEATHER_PROXY_URL" : null)
              : null,
            onToggle: (enabled) {
              HapticFeedback.lightImpact();
              _manager.setLayerEnabled(WeatherLayerType.rain, enabled);
            },
            onOpacityChanged: (opacity) {
              _manager.setLayerOpacity(WeatherLayerType.rain, opacity);
            },
          ),
          const SizedBox(height: AppTheme.spacingSM),
          _LayerControl(
            title: "Heat",
            icon: Icons.whatshot,
            iconColor: Colors.orange,
            enabled: _manager.getLayerConfig(WeatherLayerType.heat).enabled,
            opacity: _manager.getLayerConfig(WeatherLayerType.heat).opacity,
            available: WeatherConfig.isLayerAvailableOnWeb(WeatherLayerType.heat),
            unavailableMessage: !WeatherConfig.isLayerAvailableOnWeb(WeatherLayerType.heat)
              ? (kIsWeb ? "Requires API key or backend proxy. Set OPENWEATHERMAP_API_KEY or WEATHER_PROXY_URL" : null)
              : null,
            onToggle: (enabled) {
              HapticFeedback.lightImpact();
              _manager.setLayerEnabled(WeatherLayerType.heat, enabled);
            },
            onOpacityChanged: (opacity) {
              _manager.setLayerOpacity(WeatherLayerType.heat, opacity);
            },
          ),
          const SizedBox(height: AppTheme.spacingSM),
          _LayerControl(
            title: "Clouds",
            icon: Icons.cloud,
            iconColor: Colors.grey,
            enabled: _manager.getLayerConfig(WeatherLayerType.clouds).enabled,
            opacity: _manager.getLayerConfig(WeatherLayerType.clouds).opacity,
            available: WeatherConfig.isLayerAvailableOnWeb(WeatherLayerType.clouds),
            unavailableMessage: !WeatherConfig.isLayerAvailableOnWeb(WeatherLayerType.clouds)
              ? (kIsWeb ? "Requires API key or backend proxy. Set OPENWEATHERMAP_API_KEY or WEATHER_PROXY_URL" : null)
              : null,
            onToggle: (enabled) {
              HapticFeedback.lightImpact();
              _manager.setLayerEnabled(WeatherLayerType.clouds, enabled);
            },
            onOpacityChanged: (opacity) {
              _manager.setLayerOpacity(WeatherLayerType.clouds, opacity);
            },
          ),
          if (kIsWeb && !WeatherConfig.areLayersAvailable) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          "Weather layers require configuration on web.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.warningColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    "Option 1: Use .env file (recommended):\n"
                    "  Windows: .\\run-with-env.ps1\n"
                    "  Linux/Mac: ./run-with-env.sh\n\n"
                    "Option 2: Direct --dart-define:\n"
                    "  flutter run --dart-define=OPENWEATHERMAP_API_KEY=your_api_key\n\n"
                    "Option 3: Use backend proxy:\n"
                    "  flutter run --dart-define=WEATHER_PROXY_URL=http://your-backend.com",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.warningColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// * Individual layer control
class _LayerControl extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final bool enabled;
  final double opacity;
  final bool available;
  final String? unavailableMessage;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onOpacityChanged;
  
  const _LayerControl({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.enabled,
    required this.opacity,
    this.available = true,
    this.unavailableMessage,
    required this.onToggle,
    required this.onOpacityChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? iconColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Flexible(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Switch(
              value: enabled,
              onChanged: available ? onToggle : null,
              activeColor: iconColor,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: AppTheme.spacingXS),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.opacity,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Flexible(
                child: Slider(
                  value: opacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: iconColor,
                  inactiveColor: AppTheme.borderColor,
                  onChanged: onOpacityChanged,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  "${(opacity * 100).round()}%",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
        if (!available && unavailableMessage != null) ...[
          const SizedBox(height: AppTheme.spacingXS),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 12,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Flexible(
                child: Text(
                  unavailableMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warningColor,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// * Compact weather layer toggle button
class WeatherLayerToggleButton extends StatelessWidget {
  final WeatherLayerManager manager;
  final VoidCallback? onPressed;
  
  const WeatherLayerToggleButton({
    super.key,
    required this.manager,
    this.onPressed,
  });
  
  /// * Check if any layer is enabled
  bool _hasAnyLayerEnabled() {
    return manager.getLayerConfig(WeatherLayerType.rain).enabled ||
        manager.getLayerConfig(WeatherLayerType.heat).enabled ||
        manager.getLayerConfig(WeatherLayerType.clouds).enabled;
  }
  
  @override
  Widget build(BuildContext context) {
    final hasLayers = _hasAnyLayerEnabled();
    
    return FloatingActionButton.small(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed?.call();
      },
      backgroundColor: hasLayers 
          ? AppTheme.primaryColor 
          : AppTheme.surfaceColor,
      shape: const CircleBorder(),
      child: Icon(
        hasLayers ? Icons.layers : Icons.layers_outlined,
        color: hasLayers 
            ? Colors.white 
            : AppTheme.textSecondary,
      ),
    );
  }
}

