import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:geolocator/geolocator.dart";
import "package:dio/dio.dart";
import "../../providers/hazards_provider.dart";
import "../../providers/location_provider.dart";
import "../../models/hazard.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_theme.dart";
import "../../widgets/hazard_marker.dart";
import "../../widgets/hazard_detail_sheet.dart";
import "../../widgets/hoa_gate_marker.dart";
import "../../widgets/route_preview_sheet.dart";
import "../../widgets/weather_tile_layers.dart";
import "../../widgets/weather_layer_controls.dart";
import "../../services/weather_layer_manager.dart";
import "../../config/weather_config.dart";
import "../../services/location_service.dart";
import "../../services/routing_service.dart";
import "../../services/route_distance_tracker.dart";
import "../../services/location_search_service.dart";
import "../../providers/hazards_provider.dart" show MapHazardsNotifier;
import "../../providers/sticker_provider.dart";
import "../../models/sticker.dart";
import "../../widgets/distance_indicator_widget.dart";
import "../../widgets/traffic_layer.dart";
import "../../widgets/map_filter_panel.dart";
import "../../providers/map_filter_provider.dart";
// * Route utilities removed - using inline functions

/// * Navigation overlay widget
class _NavigationOverlay extends StatelessWidget {
  final String mode;
  final LatLng destination;
  final VoidCallback onStop;
  final VoidCallback? onChangeRoute;
  final double? remainingDistance;
  final Duration? remainingDuration;
  final bool isOffRoute;

  const _NavigationOverlay({
    required this.mode,
    required this.destination,
    required this.onStop,
    this.onChangeRoute,
    this.remainingDistance,
    this.remainingDuration,
    this.isOffRoute = false,
  });

  String _getModeName(String mode) {
    switch (mode) {
      case 'car':
        return 'Car';
      case 'motorcycle_sub400':
        return 'Motorcycle (≤399cc)';
      case 'motorcycle_400plus':
        return 'Big Bike (400cc+)';
      case 'truck':
        return 'Truck';
      case 'pedestrian':
        return 'Pedestrian';
      default:
        return 'Navigation';
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'car':
        return Icons.directions_car;
      case 'motorcycle_sub400':
        return Icons.two_wheeler;
      case 'motorcycle_400plus':
        return Icons.motorcycle;
      case 'truck':
        return Icons.local_shipping;
      case 'pedestrian':
        return Icons.directions_walk;
      default:
        return Icons.navigation;
    }
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'car':
        return AppTheme.primaryColor;
      case 'motorcycle_sub400':
        return AppTheme.secondaryColor;
      case 'motorcycle_400plus':
        return AppTheme.secondaryColor.withOpacity(0.8);
      case 'truck':
        return AppTheme.warningColor;
      case 'pedestrian':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.5,
        ),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: _getModeColor(mode).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(
              _getModeIcon(mode),
              color: _getModeColor(mode),
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Navigating (${_getModeName(mode)})",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isOffRoute)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSM,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Text(
                              "Off Route",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (remainingDistance != null && remainingDistance! > 0) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        "${remainingDistance!.toStringAsFixed(1)} km remaining",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (remainingDuration != null && remainingDuration!.inMinutes > 0) ...[
                        const SizedBox(width: AppTheme.spacingMD),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          "${remainingDuration!.inMinutes} min",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else
                  Text(
                    "${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          if (onChangeRoute != null)
            IconButton(
              icon: const Icon(Icons.route),
              onPressed: () {
                HapticFeedback.lightImpact();
                onChangeRoute!();
              },
              tooltip: "Change Route",
              color: AppTheme.textSecondary,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onStop();
            },
            tooltip: "Stop Navigation",
            color: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }
}

/// * Direction option item
class _DirectionOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isActive;

  const _DirectionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            color: isActive ? AppTheme.primaryColor.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// * Location options bottom sheet (like Waze/Google Maps)
class _LocationOptionsSheet extends StatelessWidget {
  final LatLng location;
  final String locationName;
  final String? address;
  final VoidCallback onGetDirections;
  final VoidCallback onSaveLocation;
  final VoidCallback onViewOnMap;
  final VoidCallback onShare;

  const _LocationOptionsSheet({
    required this.location,
    required this.locationName,
    this.address,
    required this.onGetDirections,
    required this.onSaveLocation,
    required this.onViewOnMap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // * Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppTheme.spacingSM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            // * Location name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (address != null) ...[
                              const SizedBox(height: AppTheme.spacingXS),
                              Text(
                                address!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * Coordinates
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: AppTheme.spacingSM),
                        Text(
                          "${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            // * Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
              child: Column(
                children: [
                  // * Get Directions button (primary)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onGetDirections();
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text(
                        "Get Directions",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * Secondary actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onSaveLocation();
                          },
                          icon: const Icon(Icons.bookmark_border),
                          label: const Text("Save"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onShare();
                          },
                          icon: const Icon(Icons.share),
                          label: const Text("Share"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * View on Map button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onViewOnMap();
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text("View on Map"),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
          ],
        ),
      ),
    );
  }
}

/// * Map control button widget
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? backgroundColor;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: backgroundColor != null ? Colors.white : AppTheme.textPrimary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// * Map screen showing hazards on OpenStreetMap
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  LatLng _currentLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
  Hazard? _selectedHazard;
  bool _isInitialized = false;
  MapHazardsNotifier? _hazardsNotifier;
  
  // * Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  bool _showFilterPanel = false;
  int _visibleSearchResults = 10; // * Show first 10 results initially
  final Dio _dio = Dio();
  // * Cache route distances for search results
  final Map<String, double?> _searchResultDistances = {};
  final Map<String, bool> _searchResultDistanceLoading = {};
  final RoutingService _routingService = RoutingService();
  final RouteDistanceTracker _distanceTracker = RouteDistanceTracker();
  final WeatherLayerManager _weatherLayerManager = WeatherLayerManager();
  final LocationSearchService _locationSearchService = LocationSearchService();
  StreamSubscription<Position>? _positionSubscription;
  bool _hasPreciseLocation = false;
  // * Cache country code to avoid repeated reverse geocoding calls
  String? _cachedCountryCode;
  LatLng? _countryCodeLocation; // * Location where country code was detected
  String _activeRoutingProfile = "car";
  bool _avoidTollsToggle = false;
  double _routeDistance = 0.0;
  Duration _routeDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    // * Initialize map controller and location
    _mapController = MapController();
    _currentLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    _isInitialized = true;
    
    // * Listen to weather layer changes
    _weatherLayerManager.addListener(() {
      if (mounted) {
        setState(() {}); // * Rebuild to update weather layers
      }
    });
    
    _startLocationStream();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      _loadCurrentLocation();
        // * Load hazards after a short delay to ensure map is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _onMapReady();
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dio.close();
    _weatherLayerManager.dispose();
    // * RoutingService doesn't need dispose
    super.dispose();
  }
  
  /// * Detect country code from current location
  /// * Caches the result to avoid repeated reverse geocoding calls
  Future<void> _detectCountryCode() async {
    // * Skip if we already have a cached country code for this location
    if (_cachedCountryCode != null && 
        _countryCodeLocation != null &&
        _currentLocation.latitude == _countryCodeLocation!.latitude &&
        _currentLocation.longitude == _countryCodeLocation!.longitude) {
      return;
    }
    
    // * Skip if location is at default (0,0) or invalid
    if (_currentLocation.latitude == 0.0 && _currentLocation.longitude == 0.0) {
      return;
    }
    
    if (_currentLocation.latitude == AppConstants.defaultLatitude && 
        _currentLocation.longitude == AppConstants.defaultLongitude) {
      return;
    }
    
    try {
      final countryCode = await _locationSearchService.getCountryCodeFromCoordinates(
        _currentLocation.latitude,
        _currentLocation.longitude,
      );
      
      if (countryCode != null && mounted) {
        setState(() {
          _cachedCountryCode = countryCode;
          _countryCodeLocation = _currentLocation;
        });
        debugPrint("🌍 [MapScreen] Detected country code: $countryCode");
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error detecting country code: $e");
    }
  }
  
  /// * Check if a result is a main city/town (for filtering global results)
  bool _isMainCity(Map<String, dynamic> result) {
    final type = result['type']?.toString().toLowerCase() ?? '';
    final classType = result['class']?.toString().toLowerCase() ?? '';
    final importance = (result['importance'] as num?)?.toDouble() ?? 0.0;
    
    // * Main city types
    final mainCityTypes = [
      'city', 'town', 'village', 'municipality', 'administrative',
      'state', 'province', 'region', 'country'
    ];
    
    // * Check if it's a main city type
    if (mainCityTypes.contains(type) || mainCityTypes.contains(classType)) {
      return true;
    }
    
    // * Also accept places with high importance (typically cities)
    if (importance > 0.5) {
      return true;
    }
    
    return false;
  }
  
  /// * Search for locations using Nominatim API
  /// * Prioritizes current country results, then shows global main cities
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });
    
    // * Ensure country code is detected before searching
    if (_cachedCountryCode == null) {
      await _detectCountryCode();
    }
    
    try {
      final allResults = <Map<String, dynamic>>[];
      
      // * Step 1: Search in current country first (prioritized)
      if (_cachedCountryCode != null && _cachedCountryCode!.isNotEmpty) {
        try {
          final countryResponse = await _dio.get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': query,
              'format': 'json',
              'limit': 20, // * Get more results from current country
              'addressdetails': 1,
              'countrycodes': _cachedCountryCode!.toLowerCase(),
            },
            options: Options(
              headers: {
                'User-Agent': 'SmartRoad App',
              },
            ),
          );
          
          if (countryResponse.statusCode == 200 && countryResponse.data is List) {
            final countryResults = List<Map<String, dynamic>>.from(countryResponse.data);
            allResults.addAll(countryResults);
            debugPrint("🔍 [MapScreen] Found ${countryResults.length} results in ${_cachedCountryCode!.toUpperCase()}");
          }
        } catch (e) {
          debugPrint("⚠️ [MapScreen] Error searching in current country: $e");
        }
      }
      
      // * Step 2: Search globally but filter to main cities only
      try {
        final globalResponse = await _dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': query,
            'format': 'json',
            'limit': 30, // * Get more to filter
            'addressdetails': 1,
          },
          options: Options(
            headers: {
              'User-Agent': 'SmartRoad App',
            },
          ),
        );
        
        if (globalResponse.statusCode == 200 && globalResponse.data is List) {
          final globalResults = List<Map<String, dynamic>>.from(globalResponse.data);
          
          // * Filter to only main cities and exclude current country (already added)
          final filteredGlobal = globalResults.where((result) {
            // * Skip if already in results (from current country search)
            final resultKey = "${result['lat']}_${result['lon']}";
            final alreadyExists = allResults.any((r) => 
              "${r['lat']}_${r['lon']}" == resultKey
            );
            if (alreadyExists) return false;
            
            // * Only include main cities
            return _isMainCity(result);
          }).toList();
          
          allResults.addAll(filteredGlobal);
          debugPrint("🔍 [MapScreen] Found ${filteredGlobal.length} global main city results");
        }
      } catch (e) {
        debugPrint("⚠️ [MapScreen] Error searching globally: $e");
      }
      
      // * Remove duplicates based on coordinates
      final uniqueResults = <String, Map<String, dynamic>>{};
      for (final result in allResults) {
        final key = "${result['lat']}_${result['lon']}";
        if (!uniqueResults.containsKey(key)) {
          uniqueResults[key] = result;
        }
      }
      
      final finalResults = uniqueResults.values.toList();
      
      setState(() {
        _searchResults = finalResults;
        _isSearching = false;
        _visibleSearchResults = 10; // * Reset to show first 10 results
      });
      
      debugPrint("✅ [MapScreen] Total unique results: ${finalResults.length}");
      
      // * Calculate route distances for each result
      _calculateSearchResultDistances(finalResults);
    } catch (e) {
      debugPrint("❌ [MapScreen] Error searching location: $e");
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error searching location. Please try again."),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// * Format address from Nominatim result
  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[];
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['country'] != null) parts.add(address['country']);
    return parts.join(', ');
  }
  
  /// * Calculate route distances for search results
  /// * Uses actual route distance (not straight-line) from current location
  Future<void> _calculateSearchResultDistances(List<Map<String, dynamic>> results) async {
    // * Always calculate distances - use current location (even if it's default)
    // * This allows distance to show for all search results
    
    debugPrint("📍 [MapScreen] Calculating distances for ${results.length} search results from location: (${_currentLocation.latitude}, ${_currentLocation.longitude})");
    
    // * Clear previous distances
    setState(() {
      _searchResultDistances.clear();
      _searchResultDistanceLoading.clear();
    });
    
    // * Calculate distance for each result
    for (final result in results) {
      try {
        final lat = double.tryParse(result['lat']?.toString() ?? '');
        final lon = double.tryParse(result['lon']?.toString() ?? '');
        
        if (lat == null || lon == null) continue;
        
        final resultKey = "${result['lat']}_${result['lon']}";
        final destination = LatLng(lat, lon);
        
        // * Calculate fallback distance immediately (straight-line) so it shows right away
        final fallbackDistance = _calculateStraightLineDistance(_currentLocation, destination);
        
        // * Mark as loading and show fallback distance immediately
        setState(() {
          _searchResultDistanceLoading[resultKey] = true;
          _searchResultDistances[resultKey] = fallbackDistance; // * Show fallback while calculating route
        });
        
        // * Calculate route distance in background
        try {
          debugPrint("📍 [MapScreen] Calculating route distance from (${_currentLocation.latitude}, ${_currentLocation.longitude}) to ($lat, $lon)");
          final route = await _routingService.calculateRoute(
            start: _currentLocation,
            end: destination,
            vehicle: VehicleType.car, // * Use car as default for search results
            avoidTolls: _avoidTollsToggle,
          );
          
          debugPrint("✅ [MapScreen] Route distance calculated: ${route.distance.toStringAsFixed(2)} km");
          // * Store actual route distance in km (replaces fallback)
          if (mounted) {
            setState(() {
              _searchResultDistances[resultKey] = route.distance;
              _searchResultDistanceLoading[resultKey] = false;
            });
          }
        } catch (e) {
          // * If route calculation fails, keep the fallback distance
          debugPrint("⚠️ [MapScreen] Route calculation failed for search result: $e");
          debugPrint("⚠️ [MapScreen] Using fallback straight-line distance: ${fallbackDistance.toStringAsFixed(2)} km");
          if (mounted) {
            setState(() {
              // * Keep fallback distance, just stop loading
              _searchResultDistanceLoading[resultKey] = false;
            });
          }
        }
      } catch (e) {
        debugPrint("❌ [MapScreen] Error calculating distance for search result: $e");
        final resultKey = "${result['lat']}_${result['lon']}";
        // * On error, calculate fallback straight-line distance
        try {
          final lat = double.tryParse(result['lat']?.toString() ?? '');
          final lon = double.tryParse(result['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final destination = LatLng(lat, lon);
            final fallbackDistance = _calculateStraightLineDistance(_currentLocation, destination);
            debugPrint("📍 [MapScreen] Using fallback distance: ${fallbackDistance.toStringAsFixed(2)} km");
            if (mounted) {
              setState(() {
                _searchResultDistances[resultKey] = fallbackDistance;
                _searchResultDistanceLoading[resultKey] = false;
              });
            }
          }
        } catch (fallbackError) {
          debugPrint("❌ [MapScreen] Fallback distance calculation also failed: $fallbackError");
          if (mounted) {
            setState(() {
              _searchResultDistanceLoading[resultKey] = false;
            });
          }
        }
      }
    }
  }
  
  /// * Calculate straight-line distance (Haversine formula) as fallback
  double _calculateStraightLineDistance(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final double dLat = (end.latitude - start.latitude) * (math.pi / 180.0);
    final double dLon = (end.longitude - start.longitude) * (math.pi / 180.0);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(start.latitude * (math.pi / 180.0)) * math.cos(end.latitude * (math.pi / 180.0)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  /// * Format distance for display
  String _formatDistance(double? distanceKm) {
    if (distanceKm == null) return "";
    
    if (distanceKm < 1.0) {
      return "${(distanceKm * 1000).round()} m";
    } else if (distanceKm < 10.0) {
      return "${distanceKm.toStringAsFixed(1)} km";
    } else {
      return "${distanceKm.round()} km";
    }
  }
  
  /// * Select a search result and show options
  void _selectSearchResult(Map<String, dynamic> result) {
    try {
      final lat = double.parse(result['lat'].toString());
      final lon = double.parse(result['lon'].toString());
      final location = LatLng(lat, lon);
      
      // * Close search results
      setState(() {
        _showSearchResults = false;
        _searchFocusNode.unfocus();
      });
      
      // * Move map to location
      _mapController.move(location, 15.0);
      
      // * Show location options bottom sheet
      _showLocationOptionsSheet(result, location);
    } catch (e) {
      debugPrint("❌ [MapScreen] Error selecting search result: $e");
    }
  }
  
  /// * Show location options bottom sheet (like Waze/Google Maps)
  void _showLocationOptionsSheet(Map<String, dynamic> result, LatLng location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LocationOptionsSheet(
        location: location,
        locationName: result['display_name'] ?? 'Location',
        address: result['address'] != null
            ? _formatAddress(result['address'] as Map<String, dynamic>)
            : null,
        onGetDirections: () => _openDirections(location),
        onSaveLocation: () => _saveLocation(result),
        onViewOnMap: () {
          Navigator.of(context).pop();
          // * Map is already moved to location
        },
        onShare: () => _shareLocation(result, location),
      ),
    );
  }
  
  // * Navigation state
  bool _isNavigating = false;
  LatLng? _navigationDestination;
  String? _navigationMode; // 'car', 'motorcycle_sub400', 'motorcycle_400plus', 'truck', 'public_transit', 'tricycle'
  List<LatLng>? _navigationRoute;
  
  // * Route selection state
  List<RouteData> _availableRoutes = [];
  int _selectedRouteIndex = 0;
  
  // * Route color coding state
  List<LatLng> _traveledRoute = [];
  List<LatLng> _upcomingRoute = [];
  double _traveledDistance = 0.0;
  
  // * Weather overlay state
  bool _showWeatherControls = false;
  
  // * Off-route detection state
  bool _isOffRoute = false;
  double _offRouteDistance = 0.0;
  bool _isRerouting = false;
  DateTime? _lastRerouteTime;
  
  // * Route progress state
  double _remainingDistance = 0.0;
  Duration _remainingDuration = Duration.zero;
  
  // * Distance indicators state
  DistanceIndicators? _distanceIndicators;
  
  /// * Get navigation mode display name
  String _getNavigationModeName(String mode) {
    switch (mode) {
      case 'car':
        return 'Car';
      case 'motorcycle_sub400':
        return 'Motorcycle (Sub-400cc)';
      case 'motorcycle_400plus':
        return 'Motorcycle (400cc+)';
      case 'truck':
        return 'Truck';
      case 'public_transit':
        return 'Public Transit';
      case 'tricycle':
        return 'Tricycle';
      default:
        return 'Navigation';
    }
  }
  
  /// * Get navigation mode icon
  IconData _getNavigationModeIcon(String mode) {
    switch (mode) {
      case 'car':
        return Icons.directions_car;
      case 'motorcycle_sub400':
        return Icons.two_wheeler;
      case 'motorcycle_400plus':
        return Icons.motorcycle;
      case 'truck':
        return Icons.local_shipping;
      case 'pedestrian':
        return Icons.directions_walk;
      default:
        return Icons.navigation;
    }
  }
  
  /// * Get route color based on mode
  Color _getRouteColor(String mode) {
    switch (mode) {
      case 'car':
        return AppTheme.primaryColor;
      case 'motorcycle_sub400':
        return AppTheme.secondaryColor;
      case 'motorcycle_400plus':
        return AppTheme.secondaryColor.withOpacity(0.8);
      case 'truck':
        return AppTheme.warningColor;
      case 'pedestrian':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }
  
  /// * Start navigation (shows route preview first)
  Future<void> _startNavigation(LatLng destination, String mode) async {
    try {
      if (mounted) {
        Navigator.of(context).pop(); // * Close location options sheet
        
        // * Calculate route first
        await _calculateRoute(destination, mode);
        
        // * Show route preview sheet
        if (_availableRoutes.isNotEmpty && mounted) {
          final route = _availableRoutes[_selectedRouteIndex];
          final vehicleType = _getVehicleTypeFromMode(mode);
          final vehicleModeName = _getNavigationModeName(mode);
          
          // * Get HOA name for sticker suggestion
          String? hoaName;
          if (route.metadata?.blockedShortcut ?? false) {
            final hoasAsync = ref.read(hoasProvider);
            final hoas = await hoasAsync.when(
              data: (hoaList) => hoaList,
              loading: () => <HOA>[],
              error: (_, __) => <HOA>[],
            );
            // * Find first restricted HOA (for MVP, use first one)
            final restrictedHoa = hoas.firstWhere(
              (hoa) => hoa.isResidentsOnly,
              orElse: () => hoas.isNotEmpty ? hoas.first : HOA(
                id: "",
                name: "Restricted Area",
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
            hoaName = restrictedHoa.name;
          }
          
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => RoutePreviewSheet(
              route: route,
              vehicleType: vehicleType,
              vehicleModeName: vehicleModeName,
              onStartNavigation: () {
                Navigator.of(context).pop(); // * Close preview sheet
                _beginNavigation(destination, mode);
              },
              onCancel: () {
                Navigator.of(context).pop(); // * Close preview sheet
              },
              onApplyForSticker: route.metadata?.blockedShortcut ?? false
                  ? () {
                      Navigator.of(context).pop(); // * Close preview sheet
                      // * Navigate to stickers screen
                      // * FUTURE (Post-MVP): Navigate to sticker purchase/application screen
                      // * FUTURE (Post-MVP): Payment integration (GCash, PayMaya, Stripe)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Navigate to sticker application for $hoaName"),
                          backgroundColor: AppTheme.infoColor,
                        ),
                      );
                    }
                  : null,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error starting navigation: $e");
    }
  }
  
  /// * Begin actual navigation (after preview confirmed)
  void _beginNavigation(LatLng destination, String mode) async {
    setState(() {
      _isNavigating = true;
      _navigationDestination = destination;
      _navigationMode = mode;
      _activeRoutingProfile = mode == 'car' ? 'car' : 'motorcycle_sub400';
    });
    
    // * Initialize distance tracker
    if (_availableRoutes.isNotEmpty) {
      final route = _availableRoutes[_selectedRouteIndex];
      
      // * Get HOAs and user stickers for permission-based routing
      final hoasAsync = ref.read(hoasProvider);
      final userStickerIdsAsync = ref.read(userStickerIdsProvider);
      
      final hoas = await hoasAsync.when(
        data: (hoaList) => hoaList,
        loading: () => <HOA>[],
        error: (_, __) => <HOA>[],
      );
      
      final userStickerIds = await userStickerIdsAsync.when(
        data: (ids) => ids,
        loading: () => <String>[],
        error: (_, __) => <String>[],
      );
      
      _distanceTracker.initialize(
        route: route,
        hoas: hoas,
        userStickerIds: userStickerIds,
      );
    }
    
    // * Move map to show route
    if (_navigationRoute != null && _navigationRoute!.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_navigationRoute!),
          padding: const EdgeInsets.all(100),
        ),
      );
    }
    
    // * Show navigation started message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _getNavigationModeIcon(mode),
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Navigation started (${_getNavigationModeName(mode)} mode)"),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// * Get VehicleType from mode string
  VehicleType _getVehicleTypeFromMode(String mode) {
    switch (mode) {
      case 'motorcycle_sub400':
        return VehicleType.motorcycle;
      case 'motorcycle_400plus':
        return VehicleType.bigBike;
      case 'car':
        return VehicleType.car;
      case 'truck':
        return VehicleType.truck;
      case 'pedestrian':
        return VehicleType.pedestrian;
      default:
        return VehicleType.car;
    }
  }
  
  /// * Check if current time is within truck ban hours
  bool _isTruckBanHours() {
    final now = DateTime.now();
    final hour = now.hour;
    // * Truck ban: 6:00 AM - 10:00 AM and 5:00 PM - 10:00 PM
    return (hour >= 6 && hour < 10) || (hour >= 17 && hour < 22);
  }
  
  /// * Check if route contains expressway segments
  /// * Uses known Philippine expressway bounding boxes
  bool _routeContainsExpressway(List<dynamic> coordinates) {
    // * Known Philippine expressway bounding boxes (approximate)
    // * NLEX: 14.5-15.2°N, 120.5-121.0°E
    // * SLEX: 14.0-14.6°N, 120.9-121.2°E
    // * CAVITEX: 14.3-14.5°N, 120.8-121.0°E
    // * TPLEX: 15.4-16.5°N, 120.2-120.8°E
    // * Skyway: 14.4-14.6°N, 121.0-121.1°E
    
    final expresswayBounds = [
      {'name': 'NLEX', 'latMin': 14.5, 'latMax': 15.2, 'lngMin': 120.5, 'lngMax': 121.0},
      {'name': 'SLEX', 'latMin': 14.0, 'latMax': 14.6, 'lngMin': 120.9, 'lngMax': 121.2},
      {'name': 'CAVITEX', 'latMin': 14.3, 'latMax': 14.5, 'lngMin': 120.8, 'lngMax': 121.0},
      {'name': 'TPLEX', 'latMin': 15.4, 'latMax': 16.5, 'lngMin': 120.2, 'lngMax': 120.8},
      {'name': 'Skyway', 'latMin': 14.4, 'latMax': 14.6, 'lngMin': 121.0, 'lngMax': 121.1},
    ];
    
    for (var coord in coordinates) {
      final lat = coord[1] as double;
      final lng = coord[0] as double;
      
      for (var bound in expresswayBounds) {
        final latMin = bound['latMin'] as double;
        final latMax = bound['latMax'] as double;
        final lngMin = bound['lngMin'] as double;
        final lngMax = bound['lngMax'] as double;
        if (lat >= latMin && lat <= latMax &&
            lng >= lngMin && lng <= lngMax) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  
  /// * Calculate route using SmartRoad backend API (MVP)
  /// * 
  /// * [destination] - Destination point
  /// * [mode] - Navigation mode
  /// * [origin] - Optional origin point (defaults to current location)
  Future<void> _calculateRoute(LatLng destination, String mode, {LatLng? origin}) async {
    try {
      final routeOrigin = origin ?? _currentLocation;
      
      // * Map mode to backend API format
      String backendMode;
      bool avoidTolls = false;
      
      switch (mode) {
        case 'car':
          backendMode = 'car';
          avoidTolls = _avoidTollsToggle;
          break;
        case 'motorcycle_sub400':
          backendMode = 'motorcycle';
          avoidTolls = true; // * Standard motorcycles always avoid tolls
          break;
        case 'motorcycle_400plus':
          backendMode = 'motorcycle';
          avoidTolls = _avoidTollsToggle; // * Big bikes allow tolls like cars
          break;
        case 'truck':
          backendMode = 'truck';
          avoidTolls = _avoidTollsToggle;
          break;
        case 'pedestrian':
          backendMode = 'foot';
          avoidTolls = true; // * Pedestrians don't use tolls
          break;
        default:
          backendMode = 'car';
          avoidTolls = _avoidTollsToggle;
      }
      
      debugPrint("📍 [MapScreen] Calculating route: mode=$backendMode, avoidTolls=$avoidTolls");
      
      // * Get user sticker IDs for permission-based routing
      final userStickerIdsAsync = ref.read(userStickerIdsProvider);
      final userStickerIds = await userStickerIdsAsync.when(
        data: (ids) => ids,
        loading: () => <String>[],
        error: (_, __) => <String>[],
      );
      
      // * Get HOA IDs for restricted roads
      final hoasAsync = ref.read(hoasProvider);
      final hoas = await hoasAsync.when(
        data: (hoaList) => hoaList,
        loading: () => <HOA>[],
        error: (_, __) => <HOA>[],
      );
      // * Get restricted HOA IDs (HOAs with residents_only access type)
      final restrictedHoaIds = hoas
          .where((hoa) => hoa.isResidentsOnly)
          .map((hoa) => hoa.id)
          .toList();
      
      // * Map backend mode to VehicleType
      VehicleType vehicleType;
      switch (mode) {
        case 'motorcycle_sub400':
          vehicleType = VehicleType.motorcycle;
          break;
        case 'motorcycle_400plus':
          vehicleType = VehicleType.bigBike;
          break;
        case 'car':
          vehicleType = VehicleType.car;
          break;
        case 'truck':
          vehicleType = VehicleType.truck;
          break;
        case 'pedestrian':
          vehicleType = VehicleType.pedestrian;
          break;
        default:
          vehicleType = VehicleType.car;
      }
      
      // * Call routing service with permission-based routing
      final route = await _routingService.calculateRoute(
        start: routeOrigin,
        end: destination,
        vehicle: vehicleType,
        avoidTolls: avoidTolls,
        userStickerIds: userStickerIds,
        restrictedHoaIds: restrictedHoaIds,
      );
      
      // * Store route
      setState(() {
        _availableRoutes = [route]; // * Single route for now
        _selectedRouteIndex = 0;
        
        // * Use primary route
        _navigationRoute = route.points;
        _routeDistance = route.distance; // * Already in km
        _routeDuration = route.duration;
        
        // * Initialize route segments
        _updateRouteSegments();
      });
      
      debugPrint("📍 [MapScreen] Route calculated: "
          "${_routeDistance.toStringAsFixed(2)} km, "
          "${(_routeDuration.inMinutes).toStringAsFixed(1)} min");
      
      // * Show info if tolls are being avoided
      if (avoidTolls && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.infoColor.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Text(
                      "Route calculated avoiding toll roads",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      debugPrint("❌ [MapScreen] Error calculating route: $e");
      if (mounted) {
        final errorMessage = e.toString();
        final isConnectionError = errorMessage.contains("Cannot connect") || 
                                  errorMessage.contains("connection error") ||
                                  errorMessage.contains("connection timeout");
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Text(
                          isConnectionError
                              ? "Routing service unavailable"
                              : "Could not calculate route",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isConnectionError) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      "Please start the backend server:\n"
                      "1. Run 'docker-compose up -d' in project root\n"
                      "2. Or start backend manually: 'cd backend && npm start'",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            duration: Duration(seconds: isConnectionError ? 8 : 4),
          ),
        );
      }
    }
  }
  
  /// * Update route segments (traveled vs upcoming) based on current position
  void _updateRouteSegments() {
    if (_navigationRoute == null || _navigationRoute!.isEmpty || !_isNavigating) {
      _traveledRoute = [];
      _upcomingRoute = _navigationRoute ?? [];
      return;
    }
    
    // * Simple route splitting: find closest point on route
    final splitResult = _splitRouteAtPoint(
      _navigationRoute!,
      _currentLocation,
      thresholdKm: 1.0,
    );
    
    setState(() {
      _traveledRoute = splitResult['traveled'] ?? [];
      _upcomingRoute = splitResult['upcoming'] ?? [];
      
      // * Calculate remaining distance and duration
      if (_upcomingRoute.isNotEmpty) {
        _remainingDistance = _calculateRemainingDistance(_upcomingRoute, _currentLocation);
        
        // * Estimate remaining time based on average speed
        if (_routeDistance > 0 && _routeDuration.inSeconds > 0) {
          final avgSpeedKmh = (_routeDistance / _routeDuration.inHours);
          if (avgSpeedKmh > 0) {
            final remainingHours = (_remainingDistance / 1000) / avgSpeedKmh;
            _remainingDuration = Duration(seconds: (remainingHours * 3600).round());
          }
        }
      }
    });
  }
  
  /// * Check if user is off-route
  /// * Returns true if distance to route > 100m
  bool _checkOffRoute(LatLng currentPosition) {
    if (_navigationRoute == null || _navigationRoute!.isEmpty || !_isNavigating) {
      return false;
    }
    
    final distanceToRoute = _calculateDistanceToRoute(currentPosition, _navigationRoute!);
    
    setState(() {
      _offRouteDistance = distanceToRoute;
      _isOffRoute = distanceToRoute > 100.0; // * 100m threshold
    });
    
    return _isOffRoute;
  }
  
  /// * Recalculate route from current position
  Future<void> _recalculateRouteFromCurrentPosition() async {
    if (_isRerouting || _navigationDestination == null || _navigationMode == null) {
      return;
    }
    
    // * Debounce: Don't reroute if last reroute was less than 3 seconds ago
    if (_lastRerouteTime != null) {
      final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
      if (timeSinceLastReroute.inSeconds < 3) {
        debugPrint("📍 [MapScreen] Reroute debounced (${timeSinceLastReroute.inSeconds}s ago)");
        return;
      }
    }
    
    setState(() {
      _isRerouting = true;
      _lastRerouteTime = DateTime.now();
    });
    
    // * Show rerouting notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              const Expanded(
                child: Text("Recalculating route..."),
              ),
            ],
          ),
          backgroundColor: AppTheme.infoColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    try {
      // * Update traveled route to include path to current position
      if (_navigationRoute != null && _navigationRoute!.isNotEmpty) {
        final splitResult = _splitRouteAtPoint(_navigationRoute!, _currentLocation);
        _traveledRoute = splitResult['traveled'] ?? [];
      }
      
      // * Recalculate route from current position
      await _calculateRoute(
        _navigationDestination!,
        _navigationMode!,
        origin: _currentLocation,
      );
      
      // * Update route segments after recalculation
      _updateRouteSegments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Route recalculated"),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error recalculating route: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not recalculate route: ${e.toString()}"),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isRerouting = false;
      });
    }
  }
  
  /// * Show route selection bottom sheet
  void _showRouteSelectionSheet() {
    if (!mounted || _availableRoutes.isEmpty) {
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL),
          ),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // * Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppTheme.spacingMD),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Route",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      "${_availableRoutes.length} routes available",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _availableRoutes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingMD),
                        itemBuilder: (context, index) {
                          final route = _availableRoutes[index];
                          final isSelected = index == _selectedRouteIndex;
                          final distanceKm = route.distance; // * Already in km
                          final durationMin = route.duration.inMinutes;
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _selectRoute(index);
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              child: Container(
                                padding: const EdgeInsets.all(AppTheme.spacingMD),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.borderColor,
                                    width: isSelected ? 2.0 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  color: isSelected
                                      ? AppTheme.primaryColor.withOpacity(0.1)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${index + 1}",
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: isSelected ? Colors.white : AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingMD),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Route ${index + 1}",
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: AppTheme.spacingXS),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.straighten,
                                                size: 16,
                                                color: AppTheme.textSecondary,
                                              ),
                                              const SizedBox(width: AppTheme.spacingXS),
                                              Text(
                                                "${distanceKm.toStringAsFixed(1)} km",
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: AppTheme.spacingMD),
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: AppTheme.textSecondary,
                                              ),
                                              const SizedBox(width: AppTheme.spacingXS),
                                              Text(
                                                "$durationMin min",
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppTheme.primaryColor,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// * Select a route from available options
  void _selectRoute(int index) {
    if (index < 0 || index >= _availableRoutes.length) {
      return;
    }
    
    final selectedRoute = _availableRoutes[index];
    
    setState(() {
      _selectedRouteIndex = index;
      _navigationRoute = selectedRoute.points;
      _routeDistance = selectedRoute.distance; // * Already in km
      _routeDuration = selectedRoute.duration;
      
      // * Update route segments
      _updateRouteSegments();
    });
    
    // * Move map to show selected route
    if (_navigationRoute != null && _navigationRoute!.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_navigationRoute!),
          padding: const EdgeInsets.all(100),
        ),
      );
    }
  }
  
  /// * Stop navigation
  void _stopNavigation() {
    // * Reset distance tracker
    _distanceTracker.reset();
    
    setState(() {
      _isNavigating = false;
      _navigationDestination = null;
      _navigationMode = null;
      _navigationRoute = null;
      _availableRoutes = [];
      _selectedRouteIndex = 0;
      _traveledRoute = [];
      _upcomingRoute = [];
      _traveledDistance = 0.0;
      _isOffRoute = false;
      _offRouteDistance = 0.0;
      _isRerouting = false;
      _remainingDistance = 0.0;
      _remainingDuration = Duration.zero;
      _distanceIndicators = null;
    });
    
    // * Restart location stream with normal frequency (less frequent updates)
    _startLocationStream();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Navigation stopped"),
          backgroundColor: AppTheme.textSecondary,
        ),
      );
    }
  }
  
  /// * Open directions options
  Future<void> _openDirections(LatLng destination) async {
    try {
      if (mounted) {
        Navigator.of(context).pop(); // * Close location options sheet
        
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
              boxShadow: AppTheme.shadowLarge,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // * Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: AppTheme.spacingMD),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spacingXL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Start Navigation",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            "Pick a preset that matches your ride.",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingLG),
                          // * Big Bike (400cc+)
                          _DirectionOption(
                            icon: Icons.motorcycle,
                            title: "Big Bike (400cc+)",
                            subtitle: "High displacement motorcycles, tolls optional",
                            isActive: _activeRoutingProfile == 'motorcycle_400plus',
                            onTap: () => _startNavigation(destination, 'motorcycle_400plus'),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          // * Motorcycle (≤399cc)
                          _DirectionOption(
                            icon: Icons.two_wheeler,
                            title: "Motorcycle (≤399cc)",
                            subtitle: "Standard motorcycles, automatically avoids toll roads",
                            isActive: _activeRoutingProfile == 'motorcycle_sub400',
                            onTap: () => _startNavigation(destination, 'motorcycle_sub400'),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          // * Car (Private)
                          _DirectionOption(
                            icon: Icons.directions_car,
                            title: "Car (Private)",
                            subtitle: "Fastest routes, tolls optional",
                            isActive: _activeRoutingProfile == 'car',
                            onTap: () => _startNavigation(destination, 'car'),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          // * Truck
                          _DirectionOption(
                            icon: Icons.local_shipping,
                            title: "Truck",
                            subtitle: "Commercial vehicles, respects truck ban hours",
                            isActive: _activeRoutingProfile == 'truck',
                            onTap: () => _startNavigation(destination, 'truck'),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          // * Pedestrian
                          _DirectionOption(
                            icon: Icons.directions_walk,
                            title: "Pedestrian",
                            subtitle: "Walking routes, shortest paths",
                            isActive: _activeRoutingProfile == 'pedestrian',
                            onTap: () => _startNavigation(destination, 'pedestrian'),
                          ),
                          const SizedBox(height: AppTheme.spacingXL),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error opening directions: $e");
    }
  }
  
  /// * Save location
  void _saveLocation(Map<String, dynamic> result) {
    // * TODO: Implement save location functionality
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved: ${result['display_name'] ?? 'Location'}"),
          backgroundColor: AppTheme.successColor,
          action: SnackBarAction(
            label: "View",
            textColor: Colors.white,
            onPressed: () {
              // * TODO: Navigate to saved locations
            },
          ),
        ),
      );
    }
  }
  
  /// * Handle map long press - pin location and show options
  void _onMapLongPressed(LatLng point) async {
    try {
      // * Get address for the point using reverse geocoding
      final locationService = LocationService();
      // * Use a simple mock result for now (can enhance with reverse geocoding later)
      final mockResult = {
        'display_name': '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'address': null,
      };
      
      // * Move map to location
      _mapController.move(point, 15.0);
      
      // * Show location options sheet (same as search result)
      _showLocationOptionsSheet(mockResult, point);
    } catch (e) {
      debugPrint("❌ [MapScreen] Error handling long press: $e");
    }
  }
  
  /// * Share location
  void _shareLocation(Map<String, dynamic> result, LatLng location) {
    // * TODO: Implement share functionality
    final shareText = "${result['display_name']}\n"
        "Location: ${location.latitude}, ${location.longitude}\n"
        "https://www.google.com/maps?q=${location.latitude},${location.longitude}";
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Location copied to clipboard"),
          backgroundColor: AppTheme.successColor,
        ),
      );
      // * Copy to clipboard
      Clipboard.setData(ClipboardData(text: shareText));
    }
  }
  
  Future<void> _startLocationStream() async {
    final locationService = LocationService();
    bool hasPermission = await locationService.isPermissionGranted();
    if (!hasPermission) {
      hasPermission = await locationService.requestPermission();
    }
    if (!hasPermission) {
      debugPrint("📍 [MapScreen] Location permission not granted, cannot start stream");
      return;
    }
    
    // * Use more frequent updates for navigation, less frequent for normal mode
    final settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _isNavigating ? 1 : 5, // * 1 meter for navigation, 5 meters for normal
    );
    
    await _positionSubscription?.cancel();
    debugPrint("📍 [MapScreen] Starting location stream (distanceFilter: ${settings.distanceFilter}m)");
    
    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        final updated = LatLng(position.latitude, position.longitude);
        if (!mounted) return;
        
        setState(() {
          _currentLocation = updated;
          _hasPreciseLocation = true;
        });
        
        // * Detect country code when location is updated (only once per significant move)
        _detectCountryCode();
        
        if (_isNavigating) {
          // * Update route segments based on current position
          _updateRouteSegments();
          
          // * Update distance indicators
          final indicators = _distanceTracker.getDistanceIndicators(updated);
          setState(() {
            _distanceIndicators = indicators;
          });
          
          // * Check if user is off-route
          final isOffRoute = _checkOffRoute(updated);
          
          // * Trigger rerouting if off-route
          if (isOffRoute && !_isRerouting) {
            _recalculateRouteFromCurrentPosition();
          }
          
          // * During navigation, keep map centered on user with smooth following
          _mapController.move(updated, _mapController.camera.zoom);
        } else {
          // * Only move map when not navigating (user can pan freely)
          // * Don't auto-center in normal mode to allow user exploration
        }
      },
      onError: (error) {
        debugPrint("❌ [MapScreen] Location stream error: $error");
        // * Try to restart stream on error
        if (mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _startLocationStream();
            }
          });
        }
      },
    );
    
    debugPrint("📍 [MapScreen] Location stream started successfully");
  }
  
  Future<void> _loadCurrentLocation() async {
    try {
      debugPrint("📍 [MapScreen] Loading current location...");
      final locationService = LocationService();
      
      // * First, try to get last known position for immediate display
      final lastKnown = await locationService.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final location = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentLocation = location;
          _hasPreciseLocation = true;
        });
        try {
          _mapController.move(location, AppConstants.defaultZoom);
          debugPrint("📍 [MapScreen] Map moved to last known location");
          // * Detect country code when location is updated
          _detectCountryCode();
        } catch (e) {
          debugPrint("❌ [MapScreen] Error moving map: $e");
        }
      }
      
      // * Then get fresh position (await it to ensure we get location)
      try {
        final position = await locationService.getCurrentPosition();
        if (!mounted) return;
        if (position != null) {
          final location = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLocation = location;
            _hasPreciseLocation = true;
          });
          if (!_isNavigating) {
            // * Only move map if not navigating (navigation mode follows user automatically)
            try {
              _mapController.move(location, _mapController.camera.zoom);
              debugPrint("📍 [MapScreen] Map moved to fresh location");
            } catch (e) {
              debugPrint("❌ [MapScreen] Error moving map: $e");
            }
          }
          debugPrint("📍 [MapScreen] Fresh location obtained: ${location.latitude}, ${location.longitude}");
          // * Detect country code when location is updated
          _detectCountryCode();
        } else {
          debugPrint("⚠️ [MapScreen] Could not get fresh location, using last known or default");
          if (lastKnown == null && mounted) {
            // * Only use default if we have no location at all
            _mapController.move(_currentLocation, AppConstants.defaultZoom);
          }
        }
      } catch (e) {
        debugPrint("❌ [MapScreen] Error getting fresh location: $e");
        if (lastKnown == null && mounted) {
          _mapController.move(_currentLocation, AppConstants.defaultZoom);
        }
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error loading location: $e");
      // * Ensure we have a valid location
      if (mounted) {
        _currentLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
      }
    }
  }
  
  Future<void> _refreshLocation({bool centerOnMap = true}) async {
    final locationService = LocationService();
    final position = await locationService.getCurrentPosition();
    if (!mounted) return;
    if (position != null) {
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = location;
        _hasPreciseLocation = true;
      });
      if (centerOnMap) {
        _mapController.move(location, AppConstants.defaultZoom);
      }
    } else {
      debugPrint("❌ [MapScreen] Unable to refresh location");
    }
  }
  
  /// * Manually request location permission and refresh location
  Future<void> _requestLocationPermission() async {
    try {
      debugPrint("📍 [MapScreen] Manually requesting location...");
      
      // * Request permission directly
      final locationService = LocationService();
      final hasPermission = await locationService.isPermissionGranted();
      
      if (!hasPermission) {
        debugPrint("📍 [MapScreen] Requesting location permission...");
        final granted = await locationService.requestPermission();
        if (!granted) {
          debugPrint("❌ [MapScreen] Location permission denied");
          // * Show a snackbar or dialog to inform user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Text(
                          "Location permission is required to show your current location",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                action: SnackBarAction(
                  label: "OK",
                  textColor: AppTheme.errorColor,
                  onPressed: () {},
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }
      
      // * Get position directly
      debugPrint("📍 [MapScreen] Getting current position...");
      final position = await locationService.getCurrentPosition();
      
      if (position != null && mounted) {
        final location = LatLng(position.latitude, position.longitude);
        debugPrint("📍 [MapScreen] Got location: ${location.latitude}, ${location.longitude}");
        
        setState(() {
          _currentLocation = location;
        });
        
        // * Move map to location
        _mapController.move(location, AppConstants.defaultZoom);
        
        // * Refresh the provider
        ref.invalidate(currentLocationProvider);
        
        // * Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location updated: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}"),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint("❌ [MapScreen] Could not get location");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Text(
                        "Could not get your location. Please check your browser settings.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(AppTheme.spacingMD),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [MapScreen] Error requesting location: $e");
      debugPrint("❌ [MapScreen] Stack: $stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Text(
                      "Error: $e",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  void _onMapReady() {
    debugPrint("🗺️ [MapScreen] _onMapReady called");
    try {
    // * Load all hazards initially (will be optimized with PostGIS RPC later)
    // * For now, load a reasonable bounding box around current location
    const offset = 0.1; // * Roughly 10km
      
      debugPrint("🗺️ [MapScreen] Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}");
      
      if (!mounted) {
        debugPrint("❌ [MapScreen] Widget not mounted, skipping _onMapReady");
        return;
      }
      
      debugPrint("🗺️ [MapScreen] Using cached notifier...");
      if (_hazardsNotifier == null) {
        debugPrint("❌ [MapScreen] ERROR: _hazardsNotifier is NULL!");
        return;
      }
      
      _hazardsNotifier!.loadHazardsInBounds(
        _currentLocation.latitude - offset,
        _currentLocation.longitude - offset,
        _currentLocation.latitude + offset,
        _currentLocation.longitude + offset,
      );
      debugPrint("🗺️ [MapScreen] loadHazardsInBounds called successfully");
    } catch (e, stackTrace) {
      debugPrint("❌ [MapScreen] ERROR in _onMapReady: $e");
      debugPrint("❌ [MapScreen] Stack: $stackTrace");
    }
  }
  
  void _onMapMoved() {
    debugPrint("🗺️ [MapScreen] _onMapMoved called");
    try {
    // * Reload hazards when map moves significantly
    // * For MVP, we'll reload all hazards (can be optimized later)
    const offset = 0.1;
      
      debugPrint("🗺️ [MapScreen] Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}");
      
      if (!mounted) {
        debugPrint("❌ [MapScreen] Widget not mounted, skipping _onMapMoved");
        return;
      }
      
      debugPrint("🗺️ [MapScreen] Using cached notifier...");
      if (_hazardsNotifier == null) {
        debugPrint("❌ [MapScreen] ERROR: _hazardsNotifier is NULL!");
        return;
      }
      
      _hazardsNotifier!.loadHazardsInBounds(
        _currentLocation.latitude - offset,
        _currentLocation.longitude - offset,
        _currentLocation.latitude + offset,
        _currentLocation.longitude + offset,
      );
      debugPrint("🗺️ [MapScreen] loadHazardsInBounds called successfully");
    } catch (e, stackTrace) {
      debugPrint("❌ [MapScreen] ERROR in _onMapMoved: $e");
      debugPrint("❌ [MapScreen] Stack: $stackTrace");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    debugPrint("🗺️ [MapScreen] build() called - START");
    
    // * Don't build map until initialized
    if (!_isInitialized) {
      debugPrint("🗺️ [MapScreen] Not initialized yet, showing loading...");
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }
    
    debugPrint("🗺️ [MapScreen] Map is initialized, building...");
    debugPrint("🗺️ [MapScreen] Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}");
    
    // * Wrap everything in error boundary
    try {
      // * Cache the notifier for use in callbacks - with error handling
      if (_hazardsNotifier == null) {
        try {
          debugPrint("🗺️ [MapScreen] Attempting to read mapHazardsProvider.notifier...");
          _hazardsNotifier = ref.read(mapHazardsProvider.notifier);
          debugPrint("🗺️ [MapScreen] Hazards notifier cached successfully");
        } catch (e, stackTrace) {
          debugPrint("❌ [MapScreen] ERROR reading mapHazardsProvider.notifier: $e");
          debugPrint("❌ [MapScreen] Stack: $stackTrace");
          // * Return error screen if we can't get the notifier
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Error initializing map",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please try again",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        debugPrint("🗺️ [MapScreen] Using cached hazards notifier");
      }
      
      // * Safely get hazards - ensure it's never null
      List<Hazard> hazards;
      try {
        debugPrint("🗺️ [MapScreen] Watching mapHazardsProvider...");
        hazards = ref.watch(mapHazardsProvider);
        debugPrint("🗺️ [MapScreen] Hazards obtained: ${hazards.length} items");
      } catch (e, stackTrace) {
        debugPrint("❌ [MapScreen] Error reading hazards provider: $e");
        debugPrint("❌ [MapScreen] Stack: $stackTrace");
        hazards = [];
      }
      
      // * Ensure _currentLocation is always valid - validate coordinates
      if (!_currentLocation.latitude.isFinite || !_currentLocation.longitude.isFinite) {
        _currentLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
      }
      
      // * Create a safe location object with explicit validation
      final safeLat = _currentLocation.latitude.isFinite 
          ? _currentLocation.latitude 
          : AppConstants.defaultLatitude;
      final safeLon = _currentLocation.longitude.isFinite 
          ? _currentLocation.longitude 
          : AppConstants.defaultLongitude;
      final safeCenter = LatLng(safeLat, safeLon);
      final currentLocationForMarker = _hasPreciseLocation ? _currentLocation : null;
    
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: safeCenter,
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              // * Enable infinite horizontal scrolling (map wrapping)
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              // * Explicitly set CRS to enable map wrapping
              // * Epsg3857 (Web Mercator) supports infinite horizontal scrolling
              crs: const Epsg3857(),
              // * Remove any bounds restrictions to allow infinite wrapping
              // * Don't set maxBounds - this would limit panning
                onMapReady: () {
                  // * Wrap in try-catch to prevent crashes
                  if (mounted) {
                    try {
                      _onMapReady();
                    } catch (e) {
                      debugPrint("Error in onMapReady: $e");
                    }
                  }
                },
              onMapEvent: (event) {
                  // * Only handle move end events to avoid excessive calls
                  if (event is MapEventMoveEnd) {
                    try {
                  _onMapMoved();
                    } catch (e, stackTrace) {
                      debugPrint("❌ [MapScreen] Error in onMapMoved callback: $e");
                      debugPrint("❌ [MapScreen] Stack: $stackTrace");
                    }
                }
              },
              onTap: (tapPosition, point) {
                  // * Close detail sheet and search results if tapping map
                  if (mounted) {
                    try {
                      setState(() {
                        _selectedHazard = null;
                        _showSearchResults = false;
                        _searchFocusNode.unfocus();
                      });
                    } catch (e) {
                      debugPrint("Error in onTap: $e");
                    }
                  }
              },
              onLongPress: (tapPosition, point) {
                  // * Long press to pin location and show options
                  if (mounted) {
                    try {
                      _onMapLongPressed(point);
                    } catch (e) {
                      debugPrint("Error in onLongPress: $e");
                    }
                  }
              },
            ),
            children: [
              // * Base map layer
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.smartroad.app", // * Package name stays lowercase (technical identifier)
                maxZoom: 19,
                // * Enable tile wrapping for infinite horizontal scrolling
                // * flutter_map handles wrapping automatically for Epsg3857 (Web Mercator)
                // * Tiles will wrap horizontally when panning left/right
              ),
              // * Traffic layer (above base map, below weather)
              Consumer(
                builder: (context, ref, child) {
                  final filterState = ref.watch(mapFilterProvider);
                  return TrafficLayer(
                    enabled: filterState.showTraffic,
                    opacity: 0.7,
                  );
                },
              ),
              // * Weather tile layers (above base map, below routes)
              // * On web, only available if backend proxy is configured (see WEATHER_LAYERS_TROUBLESHOOTING.md)
              // * On other platforms, always available
              if (WeatherConfig.areLayersAvailable && _weatherLayerManager.getLayerConfig(WeatherLayerType.rain).enabled)
                RainLayer(
                  manager: _weatherLayerManager,
                ),
              if (WeatherConfig.areLayersAvailable && _weatherLayerManager.getLayerConfig(WeatherLayerType.heat).enabled)
                HeatLayer(
                  manager: _weatherLayerManager,
                ),
              if (WeatherConfig.areLayersAvailable && _weatherLayerManager.getLayerConfig(WeatherLayerType.clouds).enabled)
                CloudLayer(
                  manager: _weatherLayerManager,
                ),
              // * Navigation route polylines (traveled and upcoming)
              if (_navigationRoute != null && _navigationRoute!.isNotEmpty)
                if (_isNavigating && (_traveledRoute.isNotEmpty || _upcomingRoute.isNotEmpty))
                  PolylineLayer(
                    polylines: [
                      // * Traveled route (light blue)
                      if (_traveledRoute.isNotEmpty)
                        Polyline(
                          points: _traveledRoute,
                          strokeWidth: 6.0,
                          color: _getRouteColor(_navigationMode ?? 'car').withOpacity(0.3),
                          borderStrokeWidth: 2.0,
                          borderColor: Colors.white.withOpacity(0.4),
                        ),
                      // * Upcoming route (full blue)
                      if (_upcomingRoute.isNotEmpty)
                        Polyline(
                          points: _upcomingRoute,
                          strokeWidth: 6.0,
                          color: _isOffRoute
                              ? AppTheme.errorColor
                              : _getRouteColor(_navigationMode ?? 'car'),
                          borderStrokeWidth: 2.0,
                          borderColor: Colors.white.withOpacity(0.8),
                        ),
                    ],
                  )
                else
                  // * Fallback: Show full route if not navigating or segments not calculated
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _navigationRoute!,
                        strokeWidth: 6.0,
                        color: _getRouteColor(_navigationMode ?? 'car'),
                        borderStrokeWidth: 2.0,
                        borderColor: Colors.white.withOpacity(0.8),
                      ),
                    ],
                  ),
              // * Navigation destination marker
              if (_navigationDestination != null && _navigationMode != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _navigationDestination!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getRouteColor(_navigationMode!),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: AppTheme.shadowLarge,
                        ),
                        child: Icon(
                          _getNavigationModeIcon(_navigationMode!),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              // * Current location marker (only show if we have a valid location)
              if (currentLocationForMarker != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocationForMarker,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: AppTheme.shadowMedium,
                        ),
                      child: const Icon(
                        Icons.navigation,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              // * Hazard markers
              MarkerLayer(
                markers: hazards
                    .where((hazard) => 
                        hazard.latitude.isFinite && 
                        hazard.longitude.isFinite &&
                        hazard.latitude != 0.0 &&
                        hazard.longitude != 0.0)
                    .map((hazard) {
                  return Marker(
                    point: LatLng(hazard.latitude, hazard.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        if (mounted) {
                        setState(() => _selectedHazard = hazard);
                        }
                      },
                      child: HazardMarker(hazard: hazard),
                    ),
                  );
                }).toList(),
              ),
              // * HOA Gate markers
              _buildHOAMarkers(),
            ],
          ),
            // * Map Controls - Top Right (below search bar)
            Positioned(
              top: 80, // * Below search bar
              right: AppTheme.spacingMD,
              child: Column(
                children: [
                  // * Zoom In Button
                  _MapControlButton(
                    icon: Icons.add,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        (currentZoom + 1).clamp(AppConstants.minZoom, AppConstants.maxZoom),
                      );
                    },
                    tooltip: "Zoom in",
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  // * Zoom Out Button
                  _MapControlButton(
                    icon: Icons.remove,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        (currentZoom - 1).clamp(AppConstants.minZoom, AppConstants.maxZoom),
                      );
                    },
                    tooltip: "Zoom out",
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * Location Button
                  _MapControlButton(
                    icon: _isNavigating ? Icons.navigation : Icons.gps_fixed,
                    onPressed: _hasPreciseLocation
                        ? () {
                            // * Center on current location
                            _mapController.move(_currentLocation, AppConstants.defaultZoom);
                          }
                        : _requestLocationPermission,
                    tooltip: _hasPreciseLocation
                        ? (_isNavigating ? "Center on my location" : "Center on my location")
                        : "Get my location",
                    backgroundColor: _hasPreciseLocation
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
            // * Search Bar - Top Center
            Positioned(
              top: AppTheme.spacingMD,
              left: AppTheme.spacingMD,
              right: AppTheme.spacingMD,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(
                      color: AppTheme.borderColor,
                      width: 1.5,
                    ),
                    boxShadow: AppTheme.shadowLarge,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: "Search location...",
                        prefixIcon: _isSearching
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.search,
                                color: AppTheme.textSecondary,
                              ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _showSearchResults = false;
                                  });
                                },
                                tooltip: "Clear",
                              ),
                            Tooltip(
                              message: "Hazards in view: ${hazards.length}",
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingSM,
                                  vertical: AppTheme.spacingXS,
                                ),
                                margin: const EdgeInsets.only(right: AppTheme.spacingSM),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppTheme.warningColor,
                                    ),
                                    const SizedBox(width: AppTheme.spacingXS),
                                    Text(
                                      "${hazards.length}",
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, child) {
                                final filterState = ref.watch(mapFilterProvider);
                                return IconButton(
                                  icon: Stack(
                                    children: [
                                      Icon(
                                        Icons.filter_list,
                                        color: filterState.hasActiveFilters
                                            ? AppTheme.primaryColor
                                            : AppTheme.textSecondary,
                                      ),
                                      if (filterState.hasActiveFilters)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _showFilterPanel = !_showFilterPanel;
                                    });
                                  },
                                  tooltip: "Filter hazards & traffic",
                                );
                              },
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingMD,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                      onChanged: (value) {
                        // * Debounce search
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value && value.isNotEmpty) {
                            _searchLocation(value);
                          }
                        });
                      },
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _searchLocation(value);
                        }
                      },
                      onTap: () {
                        if (_searchResults.isNotEmpty) {
                          setState(() {
                            _showSearchResults = true;
                          });
                        }
                      },
                      ),
                      // * Search Results Dropdown
                      if (_showSearchResults && _searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: AppTheme.spacingXS),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 1.5,
                          ),
                          boxShadow: AppTheme.shadowLarge,
                        ),
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _visibleSearchResults.clamp(0, _searchResults.length),
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: AppTheme.borderColor,
                                ),
                                itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            final resultKey = "${result['lat']}_${result['lon']}";
                            final distance = _searchResultDistances[resultKey];
                            final isLoading = _searchResultDistanceLoading[resultKey] ?? false;
                            
                            return ListTile(
                              leading: Icon(
                                Icons.place,
                                color: AppTheme.primaryColor,
                              ),
                              title: Text(
                                result['display_name'] ?? 'Unknown location',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: result['address'] != null
                                  ? Text(
                                      _formatAddress(result['address'] as Map<String, dynamic>),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: distance != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDistance(distance),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isLoading) ...[
                                          const SizedBox(width: 8),
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                          ),
                                        )
                                      : null,
                              onTap: () => _selectSearchResult(result),
                              dense: true,
                            );
                          },
                              ),
                            ),
                            // * Show More button if there are more results
                            if (_visibleSearchResults < _searchResults.length)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppTheme.borderColor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.expand_more,
                                    color: AppTheme.primaryColor,
                                  ),
                                  title: Text(
                                    "Show More (${_searchResults.length - _visibleSearchResults} more)",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      // * Show 10 more results each time
                                      _visibleSearchResults = (_visibleSearchResults + 10).clamp(0, _searchResults.length);
                                    });
                                  },
                                  dense: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // * Navigation overlay (when navigating)
            if (_isNavigating && _navigationDestination != null && _navigationMode != null) ...[
              Positioned(
                top: AppTheme.spacingMD,
                left: AppTheme.spacingMD,
                right: AppTheme.spacingMD,
                child: _NavigationOverlay(
                  mode: _navigationMode!,
                  destination: _navigationDestination!,
                  onStop: _stopNavigation,
                  onChangeRoute: _availableRoutes.length > 1 ? _showRouteSelectionSheet : null,
                  remainingDistance: _remainingDistance > 0 ? _remainingDistance / 1000 : null,
                  remainingDuration: _remainingDuration,
                  isOffRoute: _isOffRoute,
                ),
              ),
              // * Distance indicators panel (below navigation overlay)
              if (_distanceIndicators != null && _distanceIndicators!.hasAny)
                Positioned(
                  top: 120, // * Below navigation overlay
                  left: AppTheme.spacingMD,
                  right: AppTheme.spacingMD,
                  child: DistanceIndicatorsPanel(
                    indicators: _distanceIndicators!,
                    compact: true,
                  ),
                ),
            ],
            // * Hazard detail bottom sheet
            if (_selectedHazard != null)
              Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: HazardDetailSheet(
                hazard: _selectedHazard!,
                  onClose: () {
                    if (mounted) {
                      setState(() => _selectedHazard = null);
                    }
                  },
              ),
            ),
          // * Filter Panel
          if (_showFilterPanel)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: MapFilterPanel(
                onClose: () {
                  setState(() {
                    _showFilterPanel = false;
                  });
                },
              ),
            ),
          // * Weather layer controls toggle button
          Positioned(
            bottom: 100, // * Above bottom navigation
            right: AppTheme.spacingMD,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                WeatherLayerToggleButton(
                  manager: _weatherLayerManager,
                  onPressed: () {
                    setState(() {
                      _showWeatherControls = !_showWeatherControls;
                    });
                  },
                ),
                if (_showWeatherControls) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  WeatherLayerControls(
                    manager: _weatherLayerManager,
                    onLayersChanged: () {
                      setState(() {}); // * Rebuild to update layers
                    },
                  ),
                ],
              ],
            ),
          ),
          // * Bottom Toolbar (removed - using main navigation bar instead)
          // * Note: Bottom toolbar removed to avoid conflict with MainNavigationScreen's bottomNavigationBar
        ],
        ),
      );
    } catch (e, stackTrace) {
      // * If there's an error building the map, show error screen
      debugPrint("Error building MapScreen: $e");
      debugPrint("Stack: $stackTrace");
      
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  "Error loading map",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Please try again",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // * Retry by rebuilding
                    setState(() {});
                  },
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  
  /// * Build HOA gate markers layer
  Widget _buildHOAMarkers() {
    final hoasAsync = ref.watch(hoasProvider);
    
    return hoasAsync.when(
      data: (hoas) {
        // * Filter HOAs with valid coordinates
        final validHOAs = hoas.where((hoa) =>
          hoa.latitude != null &&
          hoa.longitude != null &&
          hoa.latitude!.isFinite &&
          hoa.longitude!.isFinite &&
          hoa.latitude != 0.0 &&
          hoa.longitude != 0.0
        ).toList();
        
        if (validHOAs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return MarkerLayer(
          markers: validHOAs.map((hoa) {
            return Marker(
              point: LatLng(hoa.latitude!, hoa.longitude!),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                  // * Could show HOA info dialog here
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          hoa.accessType == HOAAccessType.residentsOnly
                              ? "${hoa.name}: Residents/Guests Only"
                              : "${hoa.name}: Pay-to-Pass Available",
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: HOAGateMarker(hoa: hoa),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
  
  /// * Split route at point (utility function)
  Map<String, List<LatLng>> _splitRouteAtPoint(
    List<LatLng> route,
    LatLng point,
    {double thresholdKm = 1.0}
  ) {
    if (route.isEmpty) {
      return {'traveled': [], 'upcoming': route};
    }
    
    // * Find closest point on route
    double minDistance = double.infinity;
    int closestIndex = 0;
    
    for (int i = 0; i < route.length; i++) {
      final distance = _calculateHaversineDistance(point, route[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    // * If too far from route, return full route as upcoming
    if (minDistance > thresholdKm * 1000) {
      return {'traveled': [], 'upcoming': route};
    }
    
    // * Split at closest point
    return {
      'traveled': route.sublist(0, closestIndex + 1),
      'upcoming': route.sublist(closestIndex + 1),
    };
  }
  
  /// * Calculate remaining distance along route
  double _calculateRemainingDistance(List<LatLng> route, LatLng currentLocation) {
    if (route.isEmpty) return 0.0;
    
    double totalDistance = 0.0;
    LatLng? prevPoint = currentLocation;
    
    for (final point in route) {
      if (prevPoint != null) {
        totalDistance += _calculateHaversineDistance(prevPoint, point);
      }
      prevPoint = point;
    }
    
    return totalDistance; // * Returns in meters
  }
  
  /// * Calculate distance to route (minimum distance from point to any segment)
  double _calculateDistanceToRoute(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;
    
    double minDistance = double.infinity;
    
    for (int i = 0; i < route.length - 1; i++) {
      final segmentStart = route[i];
      final segmentEnd = route[i + 1];
      
      // * Calculate distance to line segment
      final distance = _distanceToLineSegment(point, segmentStart, segmentEnd);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance; // * Returns in meters
  }
  
  /// * Calculate distance to line segment
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    // * Simplified: use distance to closest endpoint
    final distToStart = _calculateHaversineDistance(point, lineStart);
    final distToEnd = _calculateHaversineDistance(point, lineEnd);
    return distToStart < distToEnd ? distToStart : distToEnd;
  }
  
  /// * Calculate Haversine distance between two points (in meters)
  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
    const double earthRadiusM = 6371000.0; // * Earth radius in meters
    final double dLat = _toRadians(point2.latitude - point1.latitude);
    final double dLon = _toRadians(point2.longitude - point1.longitude);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(point1.latitude)) * math.cos(_toRadians(point2.latitude)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}

// * Toolbar button widget removed - no longer used
