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
import "../../models/place.dart";
import "../../models/map_poi.dart";
import "../../models/navigation_avatar_style.dart";
import "../../models/navigation_settings.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_theme.dart";
import "../../widgets/hazard_marker.dart";
import "../../widgets/hazard_detail_sheet.dart";
import "../../widgets/place_detail_sheet.dart";
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
import "../../services/known_places_service.dart";
import "../../services/poi_search_service.dart";
import "../../services/speed_limit_service.dart";
import "../../services/supabase_service.dart";
import "../../providers/map_ui_provider.dart";
import "../../providers/hazards_provider.dart" show MapHazardsNotifier;
import "../../providers/sticker_provider.dart";
import "../../providers/navigation_settings_provider.dart";
import "../../models/sticker.dart";
import "../../widgets/distance_indicator_widget.dart";
import "../../widgets/traffic_layer.dart";
import "../../widgets/map_filter_panel.dart";
import "../../widgets/save_route_dialog.dart";
import "../../widgets/route_creation_dialog.dart";
import "../../providers/map_filter_provider.dart";
import "../../providers/route_creation_provider.dart";
import "../../models/saved_route.dart";
import "../../widgets/map_poi_marker.dart";
import "../../widgets/user_location_marker.dart";
import "../../widgets/navigation_hazard_warning_banner.dart";
import "../../widgets/navigation_speed_hud.dart";
import "../../utils/polyline_smoothing.dart";
// * Route utilities removed - using inline functions

/// * Navigation overlay widget
class _NavigationOverlay extends StatelessWidget {
  final String mode;
  final LatLng destination;
  final VoidCallback onStop;
  final VoidCallback? onChangeRoute;
  final VoidCallback? onSaveRoute;
  final double? remainingDistance;
  final Duration? remainingDuration;
  final bool isOffRoute;

  const _NavigationOverlay({
    required this.mode,
    required this.destination,
    required this.onStop,
    this.onChangeRoute,
    this.onSaveRoute,
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
          if (onSaveRoute != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                HapticFeedback.lightImpact();
                onSaveRoute!();
              },
              tooltip: "Save Route",
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
  final VoidCallback onOpenCommunityPreview;
  final VoidCallback onSaveLocation;
  final VoidCallback onViewOnMap;
  final VoidCallback onShare;

  const _LocationOptionsSheet({
    required this.location,
    required this.locationName,
    this.address,
    required this.onGetDirections,
    required this.onOpenCommunityPreview,
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
                  // * Community preview (photos + likes + comments, moderated uploads)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onOpenCommunityPreview();
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text("Photos & Comments"),
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

class _UpcomingHazardWarning {
  final Hazard hazard;
  final double distanceAheadMeters;
  final bool shouldHaptic;

  const _UpcomingHazardWarning({
    required this.hazard,
    required this.distanceAheadMeters,
    required this.shouldHaptic,
  });
}

class _StableLocationResult {
  final LatLng location;
  final bool accepted;

  const _StableLocationResult({
    required this.location,
    required this.accepted,
  });
}

/// * Map screen showing hazards on OpenStreetMap
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const double _knownPlacesMinZoom = 9.0; // * Show known places earlier (was 11.0)
  static const double _dynamicPoisMinZoom = 12.0; // * Show dynamic POIs earlier (was 16.0)
  static const double _navigationFollowZoom = 16.8;
  static const Duration _navigationCameraThrottle = Duration(milliseconds: 250);

  // * Marker sizing/anchoring (Google Maps-like: icon at the point, label extends right).
  static const double _poiMarkerHeight = MapPoiMarker.markerHeight;
  static const double _poiMarkerAnchorLeft = MapPoiMarker.anchorLeftPx;
  static const double _poiMarkerAnchorTop = _poiMarkerHeight / 2;

  late final MapController _mapController;
  bool _isMapReady = false;
  double _mapZoom = AppConstants.defaultZoom;
  LatLng _mapCenter = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
  double _mapRotationDegrees = 0.0;
  LatLngBounds? _mapVisibleBounds;
  LatLng? _pendingMapMoveCenter;
  double? _pendingMapMoveZoom;
  double? _pendingMapMoveRotationDegrees;
  CameraFit? _pendingCameraFit;
  LatLng _currentLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
  double? _currentHeadingDegrees;
  Hazard? _selectedHazard;
  Place? _selectedPlace;
  List<Place> _knownPlaces = [];
  List<MapPoi> _dynamicPois = [];
  bool _isLoadingDynamicPois = false;
  Timer? _poiDebounceTimer;
  String? _lastPoiRequestKey;
  DateTime? _lastPoiFetchedAt;
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
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _zoomLimitTimer; // * Timer to enforce zoom limits
  bool _hasPreciseLocation = false;
  // * Cache country code to avoid repeated reverse geocoding calls
  String? _cachedCountryCode;
  LatLng? _countryCodeLocation; // * Location where country code was detected
  DateTime? _lastCountryCodeFetchAt;
  bool _isDetectingCountryCode = false;
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
    _mapCenter = _currentLocation;
    _mapZoom = AppConstants.defaultZoom;
    _isInitialized = true;
    
    // * Listen to weather layer changes
    _weatherLayerManager.addListener(() {
      if (mounted) {
        setState(() {}); // * Rebuild to update weather layers
      }
    });
    
    _startLocationStream();
    _loadKnownPlaces();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCurrentLocation();
      }
    });
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _zoomLimitTimer?.cancel();
    _poiDebounceTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dio.close();
    _weatherLayerManager.dispose();
    // * RoutingService doesn't need dispose
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    // * Dev-friendly: re-load known places on hot reload so asset edits reflect immediately.
    if (kDebugMode) {
      KnownPlacesService().clearCache();
      _loadKnownPlaces();
    }
  }

  void _safeMoveMap(LatLng center, double zoom) {
    if (!_isMapReady) {
      _pendingMapMoveCenter = center;
      _pendingMapMoveZoom = zoom;
      _pendingMapMoveRotationDegrees = null;
      return;
    }

    try {
      _mapController.move(center, zoom);
    } catch (_) {
      // * Ignore: can happen if the controller is used during a transient rebuild.
    }
  }

  void _safeMoveAndRotateMap(LatLng center, double zoom, double rotationDegrees) {
    if (!_isMapReady) {
      _pendingMapMoveCenter = center;
      _pendingMapMoveZoom = zoom;
      _pendingMapMoveRotationDegrees = rotationDegrees;
      return;
    }

    try {
      _mapController.moveAndRotate(center, zoom, rotationDegrees);
    } catch (_) {
      // * Ignore: can happen if the controller is used during a transient rebuild.
    }
  }

  void _safeRotateMap(double rotationDegrees) {
    if (!_isMapReady) return;

    try {
      _mapController.rotate(rotationDegrees);
    } catch (_) {
      // * Ignore: can happen if the controller is used during a transient rebuild.
    }
  }

  void _safeFitCamera(CameraFit fit) {
    if (!_isMapReady) {
      _pendingCameraFit = fit;
      return;
    }

    try {
      _mapController.fitCamera(fit);
    } catch (_) {
      // * Ignore: can happen if the controller is used during a transient rebuild.
    }
  }

  void _startZoomLimitTimer() {
    _zoomLimitTimer?.cancel();
    _zoomLimitTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isMapReady) return;

      try {
        final camera = _mapController.camera;
        final currentZoom = camera.zoom;
        final currentCenter = camera.center;

        // * Enforce zoom limits (extra safety for pinch gestures)
        if (currentZoom < AppConstants.minZoom || currentZoom > AppConstants.maxZoom) {
          final clampedZoom = currentZoom.clamp(
            AppConstants.minZoom,
            AppConstants.maxZoom,
          );
          _safeMoveMap(currentCenter, clampedZoom);
          return;
        }

        // * Enforce Philippines bounds - restrict panning to Philippines area
        final philippinesBounds = LatLngBounds(
          LatLng(AppConstants.philippinesSouth, AppConstants.philippinesWest),
          LatLng(AppConstants.philippinesNorth, AppConstants.philippinesEast),
        );

        if (!philippinesBounds.contains(currentCenter)) {
          final clampedLat = currentCenter.latitude.clamp(
            AppConstants.philippinesSouth,
            AppConstants.philippinesNorth,
          );
          final clampedLon = currentCenter.longitude.clamp(
            AppConstants.philippinesWest,
            AppConstants.philippinesEast,
          );
          _safeMoveMap(LatLng(clampedLat, clampedLon), currentZoom);
        }
      } catch (_) {
        // * Ignore: camera may be temporarily unavailable during dispose/rebuild.
      }
    });
  }

  void _handleFlutterMapReady() {
    if (!mounted || _isMapReady) return;

    try {
      final camera = _mapController.camera;
      setState(() {
        _isMapReady = true;
        _mapZoom = camera.zoom;
        _mapCenter = camera.center;
        _mapRotationDegrees = camera.rotation;
        _mapVisibleBounds = camera.visibleBounds;
      });
    } catch (_) {
      // * Worst case: mark as ready so queued moves can flush on the next frame.
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    }

    _startZoomLimitTimer();

    final pendingCenter = _pendingMapMoveCenter;
    final pendingZoom = _pendingMapMoveZoom;
    final pendingRotation = _pendingMapMoveRotationDegrees;
    if (pendingCenter != null && pendingZoom != null) {
      _pendingMapMoveCenter = null;
      _pendingMapMoveZoom = null;
      _pendingMapMoveRotationDegrees = null;
      if (pendingRotation != null) {
        _safeMoveAndRotateMap(pendingCenter, pendingZoom, pendingRotation);
      } else {
        _safeMoveMap(pendingCenter, pendingZoom);
      }
    }

    final pendingFit = _pendingCameraFit;
    if (pendingFit != null) {
      _pendingCameraFit = null;
      _safeFitCamera(pendingFit);
    }

    // * Kick initial loads now that we can safely use the MapController.
    _onMapReady();
    _scheduleDynamicPoiRefresh();
  }

  Future<void> _loadKnownPlaces() async {
    try {
      final places = await KnownPlacesService().getKnownPlaces(forceRefresh: kDebugMode);
      if (!mounted) return;
      setState(() {
        _knownPlaces = places;
      });
      // * Refresh POIs so duplicates (e.g., "SM City San Pablo") disappear once known places load.
      _scheduleDynamicPoiRefresh();
    } catch (e) {
      debugPrint("❌ [MapScreen] Failed to load known places: $e");
    }
  }

  String _normalizePoiName(String raw) {
    final lowered = raw.toLowerCase().trim();
    final cleaned = lowered.replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
    return cleaned.replaceAll(RegExp(r"\s+"), " ");
  }

  Set<String> _buildKnownPlaceNameIndex() {
    final index = <String>{};
    for (final place in _knownPlaces) {
      index.add(_normalizePoiName(place.name));
      for (final alias in place.aliases) {
        index.add(_normalizePoiName(alias));
      }
    }
    return index;
  }

  /// * Builds a stable community place id for any location.
  /// *
  /// * - If Nominatim provides a place_id, we use `nominatim:<place_id>` for stability.
  /// * - Otherwise we bucket by coordinates to avoid generating a new id for tiny differences.
  String _buildCommunityPlaceId({
    required LatLng location,
    String? nominatimPlaceId,
  }) {
    final raw = nominatimPlaceId?.trim();
    if (raw != null && raw.isNotEmpty && raw.toLowerCase() != "null") {
      return "nominatim:$raw";
    }

    // * 1e5 bucket ≈ 1 meter latitude. This keeps ids stable for "same" place.
    final latKey = (location.latitude * 100000).round();
    final lonKey = (location.longitude * 100000).round();
    return "loc:$latKey:$lonKey";
  }

  Place _buildCommunityPlace({
    required String name,
    required LatLng location,
    String? category,
    String? nominatimPlaceId,
  }) {
    return Place(
      id: _buildCommunityPlaceId(location: location, nominatimPlaceId: nominatimPlaceId),
      name: name.trim().isNotEmpty ? name.trim() : "Location",
      latitude: location.latitude,
      longitude: location.longitude,
      category: category?.trim(),
      aliases: const [],
    );
  }

  List<String> _poiQueriesForZoom(double zoom) {
    // * Show more POI types at higher zoom levels
    if (zoom >= 14.0) {
      return const [
        "mall",
        "terminal",
        "bus station",
        "hospital",
        "gas station",
        "school",
      ];
    }

    // * Basic POI types for lower zoom levels
    return const [
      "mall",
      "terminal",
      "bus station",
      "hospital",
    ];
  }

  String _buildPoiRequestKey({required double zoom, required LatLng center}) {
    final zoomBucket = zoom.floor(); // * Reduce refresh spam while zooming.
    final latKey = (center.latitude * 1000).round(); // ~100m-ish bucket
    final lonKey = (center.longitude * 1000).round();
    return "$zoomBucket:$latKey:$lonKey";
  }

  void _scheduleDynamicPoiRefresh() {
    if (!mounted || !_isMapReady) return;

    final zoom = _mapZoom;
    if (_isNavigating || zoom < _dynamicPoisMinZoom) {
      if (_dynamicPois.isNotEmpty) {
        setState(() => _dynamicPois = []);
      }
      return;
    }

    _poiDebounceTimer?.cancel();
    _poiDebounceTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        _loadDynamicPoisForViewport();
      }
    });
  }

  Future<void> _loadDynamicPoisForViewport() async {
    if (_isLoadingDynamicPois || !_isMapReady) return;

    final zoom = _mapZoom;
    if (_isNavigating || zoom < _dynamicPoisMinZoom) {
      return;
    }

    final now = DateTime.now();
    if (_lastPoiFetchedAt != null && now.difference(_lastPoiFetchedAt!).inSeconds < 4) {
      return;
    }

    final center = _mapCenter;
    final requestKey = _buildPoiRequestKey(zoom: zoom, center: center);
    if (_lastPoiRequestKey == requestKey &&
        _lastPoiFetchedAt != null &&
        now.difference(_lastPoiFetchedAt!).inSeconds < 20) {
      return;
    }

    setState(() => _isLoadingDynamicPois = true);
    try {
      final bounds = _mapVisibleBounds;
      if (bounds == null) return;
      final queries = _poiQueriesForZoom(zoom);

      final service = PoiSearchService();
      final futures = <Future<List<MapPoi>>>[];
      for (final query in queries) {
        futures.add(service.searchInBounds(bounds: bounds, query: query, limit: 10));
      }

      final lists = await Future.wait(futures);
      if (!mounted) return;

      final knownNameIndex = _buildKnownPlaceNameIndex();

      // * Pass 1: filter + dedupe by Nominatim place_id (poi.id)
      final byId = <String, MapPoi>{};
      for (final list in lists) {
        for (final poi in list) {
          final normalizedName = _normalizePoiName(poi.name);
          if (normalizedName.isEmpty) continue;

          // * Remove POIs that are clearly the same as our curated known places.
          if (knownNameIndex.contains(normalizedName)) {
            continue;
          }

          // * Also remove POIs too close to known places (keeps the map clean).
          final tooCloseToKnown = _knownPlaces.any((p) {
            return _calculateHaversineDistance(p.location, poi.location) < 250;
          });
          if (tooCloseToKnown) continue;

          final existing = byId[poi.id];
          if (existing == null) {
            byId[poi.id] = poi;
            continue;
          }

          final existingImportance = existing.importance ?? 0;
          final nextImportance = poi.importance ?? 0;
          if (nextImportance > existingImportance) {
            byId[poi.id] = poi;
          }
        }
      }

      // * Pass 2: secondary dedupe by (name + ~55m coordinate bucket)
      final byNameBucket = <String, MapPoi>{};
      for (final poi in byId.values) {
        final normalizedName = _normalizePoiName(poi.name);
        final latKey = (poi.latitude * 2000).round();
        final lonKey = (poi.longitude * 2000).round();
        final dedupeKey = "$normalizedName:$latKey:$lonKey";

        final existing = byNameBucket[dedupeKey];
        if (existing == null) {
          byNameBucket[dedupeKey] = poi;
          continue;
        }

        final existingImportance = existing.importance ?? 0;
        final nextImportance = poi.importance ?? 0;
        if (nextImportance > existingImportance) {
          byNameBucket[dedupeKey] = poi;
        }
      }

      final merged = byNameBucket.values.toList()
        ..sort((a, b) => (b.importance ?? 0).compareTo(a.importance ?? 0));

      // * Keep POIs limited to avoid clutter (Google Maps shows only a handful).
      final maxCount = zoom >= 15.0 ? 25 : 18; // * Show more POIs at higher zoom (was 18.0 -> 22, else 14)
      final limited = merged.take(maxCount).toList();

      setState(() {
        _dynamicPois = limited;
        _lastPoiRequestKey = requestKey;
        _lastPoiFetchedAt = now;
      });
    } catch (e) {
      debugPrint("❌ [MapScreen] Failed to load dynamic POIs: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingDynamicPois = false);
      }
    }
  }
  
  /// * Detect country code from current location
  /// * Caches the result to avoid repeated reverse geocoding calls
  Future<void> _detectCountryCode() async {
    if (_isDetectingCountryCode) {
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
    
    // * Throttle requests: country rarely changes and reverse-geocoding is expensive.
    final now = DateTime.now();
    if (_lastCountryCodeFetchAt != null &&
        now.difference(_lastCountryCodeFetchAt!).inSeconds < 30) {
      return;
    }

    // * If we already have a country code, only refresh it after moving far enough.
    if (_cachedCountryCode != null && _countryCodeLocation != null) {
      final movedMeters = _calculateHaversineDistance(_currentLocation, _countryCodeLocation!);
      if (movedMeters < 8000) {
        return;
      }
    }
    
    try {
      _isDetectingCountryCode = true;
      _lastCountryCodeFetchAt = now;

      final countryCode = await _locationSearchService.getCountryCodeFromCoordinates(
        _currentLocation.latitude,
        _currentLocation.longitude,
      );
      
      final normalized = countryCode?.trim().toLowerCase();
      if (normalized != null && normalized.isNotEmpty && mounted) {
        final previous = _cachedCountryCode?.trim().toLowerCase();
        final changed = previous != normalized;

        // * Update cached values (no UI depends directly on this).
        _cachedCountryCode = normalized;
        _countryCodeLocation = _currentLocation;

        if (changed && kDebugMode) {
          debugPrint("🌍 [MapScreen] Detected country code: $normalized");
        }
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error detecting country code: $e");
    } finally {
      _isDetectingCountryCode = false;
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
              // * Use email instead of User-Agent on web (avoids CORS/preflight failures).
              'email': 'contact@smartroad.app',
            },
            options: Options(
              headers: kIsWeb
                  ? null
                  : {
                      'User-Agent': 'SmartRoad App (contact@smartroad.app)',
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
            // * Use email instead of User-Agent on web (avoids CORS/preflight failures).
            'email': 'contact@smartroad.app',
          },
          options: Options(
            headers: kIsWeb
                ? null
                : {
                    'User-Agent': 'SmartRoad App (contact@smartroad.app)',
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
  
  /// * Handle end point selection - close dialog and calculate route safely
  Future<void> _handleEndPointSelected() async {
    if (!mounted || _customStartPoint == null || _customEndPoint == null) return;
    
    // * Store points locally to avoid state issues
    final startPoint = _customStartPoint!;
    final endPoint = _customEndPoint!;
    
    // * Update state first to stop selecting custom points
    if (mounted) {
      setState(() {
        _isSelectingCustomPoints = false;
      });
    }
    
    // * Close the selection dialog safely
    // * Use a post-frame callback to ensure we're not in the middle of a build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) return;
      
      // * Try to close dialog
      try {
        final navigator = Navigator.of(context, rootNavigator: false);
        if (navigator.canPop()) {
          navigator.pop();
        }
      } catch (e) {
        // * Dialog might already be closed, ignore
        debugPrint("⚠️ [MapScreen] Could not close dialog: $e");
      }
      
      // * Wait for dialog to fully close
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || !context.mounted) return;
      
      // * Automatically calculate route with default vehicle (car)
      try {
        await _calculateRouteWithCustomPoints(startPoint, endPoint, 'car');
      } catch (e, stackTrace) {
        debugPrint("❌ [MapScreen] Error in _handleEndPointSelected: $e");
        debugPrint("❌ [MapScreen] Stack: $stackTrace");
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error calculating route: ${e.toString()}"),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }
  
  /// * Select a search result and show options
  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    // * If in custom point selection mode, set the point instead of navigating
    if (_isSelectingCustomPoints) {
      final lat = (result['lat'] as num?)?.toDouble();
      final lon = (result['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        final point = LatLng(lat, lon);
        final wasSelectingStart = _selectingStartPoint; // * Remember before state change
        final bool justSetEndPoint = !_selectingStartPoint && _customEndPoint == null;
        
        setState(() {
          if (_selectingStartPoint) {
            _customStartPoint = point;
            _selectingStartPoint = false; // * Switch to selecting end point
          } else {
            _customEndPoint = point;
          }
          _showSearchResults = false;
          _searchController.clear();
          _searchFocusNode.unfocus();
          // * Keep _isSelectingCustomPoints true so map taps still work
          _isSelectingCustomPoints = true;
        });
        
        // * Auto-calculate route when end point is selected via search
        if (justSetEndPoint && _customStartPoint != null && _customEndPoint != null) {
          await _handleEndPointSelected();
          return;
        }
        
        // * Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasSelectingStart
                  ? "Start point selected! Now tap on map or search for END point."
                  : "End point selected! Calculating route...",
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // * Reopen the bottom sheet to show end point selection (only if start point was just set)
        if (wasSelectingStart) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _isSelectingCustomPoints) {
              _showNavigationWithCustomPointsDialog();
            }
          });
        }
        return;
      }
    }
    
    // * Original behavior for normal search
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
      _safeMoveMap(location, 15.0);
      
      // * Show location options bottom sheet
      _showLocationOptionsSheet(result, location);
    } catch (e) {
      debugPrint("❌ [MapScreen] Error selecting search result: $e");
    }
  }
  
  /// * Show location options bottom sheet (like Waze/Google Maps)
  void _showLocationOptionsSheet(Map<String, dynamic> result, LatLng location) {
    final fullName = (result["display_name"] ?? "Location").toString().trim();
    final shortName = fullName.split(",").first.trim();
    final nominatimPlaceId = result["place_id"]?.toString().trim();
    final placeType = result["type"]?.toString().trim();

    final communityPlace = _buildCommunityPlace(
      name: shortName.isNotEmpty ? shortName : fullName,
      location: location,
      category: placeType,
      nominatimPlaceId: nominatimPlaceId,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LocationOptionsSheet(
        location: location,
        locationName: fullName.isNotEmpty ? fullName : "Location",
        address:
            result["address"] != null
                ? _formatAddress(result["address"] as Map<String, dynamic>)
                : null,
        onGetDirections: () {
          Navigator.of(context).pop();
          _openDirections(location);
        },
        onOpenCommunityPreview: () {
          Navigator.of(context).pop();
          if (!mounted) return;
          setState(() {
            _selectedPlace = communityPlace;
            _selectedHazard = null;
            _showSearchResults = false;
          });
          _searchFocusNode.unfocus();
        },
        onSaveLocation: () {
          Navigator.of(context).pop();
          _saveLocation(result);
        },
        onViewOnMap: () {
          Navigator.of(context).pop();
          // * Map is already moved to location
        },
        onShare: () {
          Navigator.of(context).pop();
          _shareLocation(result, location);
        },
      ),
    );
  }
  
  // * Navigation state
  bool _isNavigating = false;
  LatLng? _navigationDestination;
  String? _navigationMode; // 'car', 'motorcycle_sub400', 'motorcycle_400plus', 'truck', 'public_transit', 'tricycle'
  List<LatLng>? _navigationRoute;

  // * Navigation camera (Google Maps / Waze-like)
  bool _isNavigationFollowing = true;
  bool _isNavigationMapRotationEnabled = true;
  DateTime? _lastNavigationCameraUpdateAt;
  
  // * Route creation state
  bool _isDrawingRoute = false;
  List<LatLng> _drawnRoutePoints = [];
  
  // * Custom point selection state
  LatLng? _customStartPoint;
  LatLng? _customEndPoint;
  bool _selectingStartPoint = true;
  bool _isSelectingCustomPoints = false;
  bool _showSheetReopenButton = false; // * Show button to reopen minimized sheet
  
  // * Route selection state
  List<RouteData> _availableRoutes = [];
  int _selectedRouteIndex = 0;
  
  // * Route editing state - draggable control points
  bool _isEditingRoute = false; // * Whether user is editing route path
  List<LatLng> _routeControlPoints = []; // * Draggable points on the route line
  int? _draggingControlPointIndex; // * Index of control point being dragged
  
  // * Route color coding state
  List<LatLng> _traveledRoute = [];
  List<LatLng> _upcomingRoute = [];
  
  // * Weather overlay state
  bool _showWeatherControls = false;
  
  // * Off-route detection state
  bool _isOffRoute = false;
  bool _isRerouting = false;
  DateTime? _lastRerouteTime;
  
  // * Route progress state
  double _remainingDistance = 0.0;
  Duration _remainingDuration = Duration.zero;
  
  // * Distance indicators state
  DistanceIndicators? _distanceIndicators;

  // * Navigation hazard warnings (Waze-style)
  Hazard? _navigationHazardWarning;
  double? _navigationHazardDistanceMeters;
  final Map<String, DateTime> _navigationHazardMutedUntil = {};
  final Map<String, DateTime> _navigationHazardHapticAt = {};

  // * Navigation speed HUD + speed limits
  double? _currentSpeedKph;
  SpeedLimitResult _speedLimitResult = const SpeedLimitResult(
    speedLimitKph: null,
    source: SpeedLimitSource.unknown,
    highwayType: null,
    wayId: null,
    rawMaxspeed: null,
  );
  bool _isOverspeeding = false;
  DateTime? _lastOverspeedHapticAt;
  DateTime? _lastSpeedLimitUpdateAt;
  LatLng? _lastSpeedLimitUpdateLocation;
  bool _isLoadingSpeedLimit = false;

  // * Route cache for fast "hazard ahead" calculations
  List<double>? _navigationRouteCumulativeMeters;
  String? _navigationRouteSignature;

  // * Location stability (filter out GPS jumps + reduce jitter)
  DateTime? _lastAcceptedLocationAt;
  LatLng? _lastAcceptedLocation;
  
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
              onSaveRoute: () {
                Navigator.of(context).pop(); // * Close preview sheet
                if (mounted) {
                  setState(() {
                    _navigationMode = mode;
                    _navigationDestination = destination;
                    _customStartPoint = _currentLocation;
                    _customEndPoint = destination;
                  });
                  _showSaveRouteDialog();
                }
              },
              onStartNavigation: () {
                Navigator.of(context).pop(); // * Close preview sheet
                _beginNavigation(destination, mode);
              },
              onCancel: () {
                Navigator.of(context).pop(); // * Close preview sheet
              },
              onEditRoute: () {
                Navigator.of(context).pop(); // * Close preview sheet
                final routeOrigin = _currentLocation;
                _startRouteEditing(destination, mode, routeOrigin);
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
    // * Expose navigation state to shared UI (e.g., global FAB).
    ref.read(mapIsNavigatingProvider.notifier).state = true;
    
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
    
    // * Navigation camera: zoom-in + follow current position (Google Maps / Waze-like).
    if (mounted) {
      setState(() {
        _isNavigationFollowing = true;
        _isNavigationMapRotationEnabled = true;
        _lastNavigationCameraUpdateAt = null;
      });
    }
    _updateNavigationCamera(_currentLocation, force: true);
    
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
 
  /// * Calculate route using SmartRoad backend API (MVP)
  /// * 
  /// * [destination] - Destination point
  /// * [mode] - Navigation mode
  /// * [origin] - Optional origin point (defaults to current location)
  /// * [waypoints] - Optional intermediate waypoints for route customization
  Future<void> _calculateRoute(LatLng destination, String mode, {LatLng? origin, List<LatLng>? waypoints}) async {
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
      
      // * Call routing service with permission-based routing and waypoints
      final route = await _routingService.calculateRoute(
        start: routeOrigin,
        end: destination,
        vehicle: vehicleType,
        avoidTolls: avoidTolls,
        userStickerIds: userStickerIds,
        restrictedHoaIds: restrictedHoaIds,
        waypoints: waypoints ?? _routeControlPoints, // * Use control points if provided
      );
      
      // * Store route - only if widget is still mounted
      if (mounted) {
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
      }
      
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
      _safeFitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_navigationRoute!),
          padding: const EdgeInsets.all(100),
        ),
      );
    }
  }
  
  /// * Show route creation dialog
  void _showRouteCreationDialog() {
    showDialog(
      context: context,
      builder: (context) => RouteCreationDialog(
        onDrawRoute: () {
          Navigator.pop(context);
          _startRouteDrawing();
        },
        onUseNavigation: () {
          Navigator.pop(context);
          _showNavigationWithCustomPointsDialog();
        },
      ),
    );
  }
  
  /// * Show dialog to select start and end points for navigation
  void _showNavigationWithCustomPointsDialog() {
    // * Don't reset existing points if they're already set
    setState(() {
      _isSelectingCustomPoints = true;
      _showSheetReopenButton = false; // * Hide reopen button when sheet is shown
      // * Only reset selectingStartPoint if we don't have a start point yet
      if (_customStartPoint == null) {
        _selectingStartPoint = true;
      } else {
        _selectingStartPoint = false; // * Move to end point selection
      }
      // * Don't reset _customStartPoint and _customEndPoint if they're already set
      // * This allows the dialog to be reopened without losing progress
    });
    
    // * Create controller for DraggableScrollableSheet
    final draggableController = DraggableScrollableController();
    
    // * Listen to sheet size changes to show/hide reopen button
    draggableController.addListener(() {
      final size = draggableController.size;
      if (mounted) {
        setState(() {
          // * Show reopen button when sheet is minimized (at or near minChildSize)
          _showSheetReopenButton = size <= 0.15; // * Slightly above 0.1 to account for snap
        });
      }
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3), // * Semi-transparent barrier
      isDismissible: false, // * Prevent accidental dismissal - user must use buttons
      enableDrag: true, // * Allow dragging to minimize
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            controller: draggableController,
            initialChildSize: 0.4, // * Larger initial size for better visibility
            minChildSize: 0.1, // * Can be minimized to just a small bar (10%) to see map
            maxChildSize: 0.7,
            expand: false,
            snap: true, // * Snap to min/max sizes for better UX
            snapSizes: const [0.1, 0.4, 0.7], // * Snap points: minimized, default, expanded
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // * Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // * Title with close button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectingStartPoint
                                ? "Select START Point"
                                : "Select END Point",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility_off, size: 20),
                          tooltip: "Hide sheet (tap map to select)",
                          onPressed: () {
                            // * Hide sheet but maintain state so map taps work
                            Navigator.pop(context);
                            // * State is maintained - _isSelectingCustomPoints stays true
                            // * Show floating button to reopen sheet
                            setState(() {
                              _showSheetReopenButton = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _selectingStartPoint
                                      ? "Sheet hidden. Tap on map to select START point."
                                      : "Sheet hidden. Tap on map to select END point.",
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              // * Only reset if user explicitly cancels
                              _isSelectingCustomPoints = false;
                              _customStartPoint = null;
                              _customEndPoint = null;
                              _selectingStartPoint = true;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // * Instructions with minimize hint
                    Card(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectingStartPoint
                                        ? "Tap anywhere on the map to set START point"
                                        : "Tap anywhere on the map to set END point",
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.arrow_downward, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  "Drag down or tap minimize to see more of the map",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // * Start Point
                    if (_customStartPoint != null)
                      Card(
                        color: AppTheme.successColor.withOpacity(0.1),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.green, size: 32),
                          title: const Text("Start Point", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${_customStartPoint!.latitude.toStringAsFixed(6)}, ${_customStartPoint!.longitude.toStringAsFixed(6)}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              setDialogState(() {
                                _selectingStartPoint = true;
                                _customStartPoint = null;
                              });
                              setState(() {
                                _selectingStartPoint = true;
                                _customStartPoint = null;
                              });
                            },
                          ),
                        ),
                      ),
                    // * End Point
                    if (_customEndPoint != null)
                      Card(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.flag, color: Colors.red, size: 32),
                          title: const Text("End Point", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${_customEndPoint!.latitude.toStringAsFixed(6)}, ${_customEndPoint!.longitude.toStringAsFixed(6)}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              setDialogState(() {
                                _selectingStartPoint = false;
                                _customEndPoint = null;
                              });
                              setState(() {
                                _selectingStartPoint = false;
                                _customEndPoint = null;
                              });
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // * Use Current Location button - Only show when selecting start point
                    if (_selectingStartPoint)
                      ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            _customStartPoint = _currentLocation;
                            _selectingStartPoint = false; // * Switch to selecting end point
                          });
                          setState(() {
                            _customStartPoint = _currentLocation;
                            _selectingStartPoint = false; // * Switch to selecting end point
                            // * Ensure _isSelectingCustomPoints stays true so map taps work even when minimized
                            _isSelectingCustomPoints = true;
                          });
                          // * Show feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Start point set! Now tap on map to select END point."),
                              duration: Duration(seconds: 2),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                          // * Expand sheet slightly to show end point selection
                          draggableController.animateTo(
                            0.4,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        icon: const Icon(Icons.my_location),
                        label: const Text("Use Current Location as Start"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    if (_selectingStartPoint) const SizedBox(height: 12),
                    // * Search for location - Only show when selecting start point
                    if (_selectingStartPoint)
                      OutlinedButton.icon(
                        onPressed: () {
                          // * Minimize sheet instead of closing to maintain state
                          draggableController.animateTo(
                            0.1, // * Minimize to small size
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          // * Focus search bar and show search results in main screen
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) {
                              _searchFocusNode.requestFocus();
                              setState(() {
                                _showSearchResults = true;
                                // * Ensure state is maintained
                                _isSelectingCustomPoints = true;
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.search),
                        label: const Text("Search for Start Location"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    // * Show message when start point is selected
                    if (!_selectingStartPoint && _customStartPoint != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Start point selected. Now tap on the map to select END point",
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // * Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                // * Only reset if user explicitly cancels
                                _isSelectingCustomPoints = false;
                                _customStartPoint = null;
                                _customEndPoint = null;
                                _selectingStartPoint = true;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _customStartPoint != null && _customEndPoint != null
                                ? () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _isSelectingCustomPoints = false;
                                    });
                                    _selectVehicleAndCalculateRoute(_customStartPoint!, _customEndPoint!);
                                  }
                                : null,
                            child: const Text("Calculate Route"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // * Don't reset _isSelectingCustomPoints when sheet is dismissed
    // * Only reset when user explicitly cancels or completes the flow
    // * This allows map taps to work even when sheet is minimized
  }
  
  /// * Select vehicle type and calculate route
  void _selectVehicleAndCalculateRoute(LatLng start, LatLng end) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Vehicle Type"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _VehicleOptionButton(
              icon: Icons.directions_car,
              label: "Car",
              onTap: () {
                Navigator.pop(context);
                _calculateRouteWithCustomPoints(start, end, 'car');
              },
            ),
            const SizedBox(height: 8),
            _VehicleOptionButton(
              icon: Icons.two_wheeler,
              label: "Motorcycle (≤399cc)",
              onTap: () {
                Navigator.pop(context);
                _calculateRouteWithCustomPoints(start, end, 'motorcycle_sub400');
              },
            ),
            const SizedBox(height: 8),
            _VehicleOptionButton(
              icon: Icons.motorcycle,
              label: "Big Bike (400cc+)",
              onTap: () {
                Navigator.pop(context);
                _calculateRouteWithCustomPoints(start, end, 'motorcycle_400plus');
              },
            ),
            const SizedBox(height: 8),
            _VehicleOptionButton(
              icon: Icons.local_shipping,
              label: "Truck",
              onTap: () {
                Navigator.pop(context);
                _calculateRouteWithCustomPoints(start, end, 'truck');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
  
  /// * Vehicle option button widget
  Widget _VehicleOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppTheme.primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  /// * Start route editing mode (adjust route path to follow correct roads)
  /// * Load a saved route for editing
  void _loadRouteForEditing(SavedRoute route) {
    if (route.geometry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route has no geometry to edit")),
      );
      return;
    }
    
    // * Set route geometry
    setState(() {
      _navigationRoute = route.geometry;
      _navigationDestination = route.endPoint;
      _customStartPoint = route.startPoint;
      _customEndPoint = route.endPoint;
      
      // * Determine vehicle mode from route
      String mode;
      switch (route.vehicleType) {
        case VehicleType.motorcycle:
          mode = 'motorcycle_sub400';
          break;
        case VehicleType.bigBike:
          mode = 'motorcycle_400plus';
          break;
        case VehicleType.car:
          mode = 'car';
          break;
        case VehicleType.truck:
          mode = 'truck';
          break;
        case VehicleType.pedestrian:
          mode = 'pedestrian';
          break;
      }
      _navigationMode = mode;
      
      // * Calculate distance and duration from route
      _routeDistance = route.distanceKm;
      _routeDuration = route.duration;
      
      // * Enable editing mode
      _isEditingRoute = true;
      _routeControlPoints = [];
      _draggingControlPointIndex = null;
    });
    
    // * Fit map to route
    if (route.geometry.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(route.geometry);
      _safeFitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
    
    // * Show editing instructions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Route loaded for editing. Tap on the route line to add control points. Tap a control point to move it."),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: "Done",
          onPressed: () {
            setState(() {
              _isEditingRoute = false;
            });
          },
        ),
      ),
    );
  }
  
  void _startRouteEditing(LatLng destination, String mode, LatLng start) {
    // * Enable route path editing mode
    // * User can tap on the route line to add control points, then drag them to adjust the path
    if (_navigationRoute == null || _navigationRoute!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No route to edit")),
      );
      return;
    }
    
    setState(() {
      _isEditingRoute = true;
      _routeControlPoints = []; // * Clear existing control points
      _draggingControlPointIndex = null;
      // * Store navigation info for recalculation
      if (_navigationDestination == null) {
        _navigationDestination = destination;
      }
      if (_navigationMode == null) {
        _navigationMode = mode;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Tap on the route line to add control points. Tap a control point to move it and adjust the route path."),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "Done",
          onPressed: () {
            setState(() {
              _isEditingRoute = false;
              _routeControlPoints = [];
            });
          },
        ),
      ),
    );
  }
  
  /// * Find the nearest point on the route line to the tap position
  /// * Checks distance to line segments, not just route points
  LatLng? _findNearestRoutePoint(LatLng tapPoint) {
    if (_navigationRoute == null || _navigationRoute!.isEmpty) return null;
    
    double minDistance = double.infinity;
    LatLng? nearestPointOnLine;
    
    // * Check distance to each line segment
    for (int i = 0; i < _navigationRoute!.length - 1; i++) {
      final p1 = _navigationRoute![i];
      final p2 = _navigationRoute![i + 1];
      
      // * Calculate distance from tap point to line segment
      final distanceToSegment = _distanceToLineSegment(tapPoint, p1, p2);
      
      if (distanceToSegment['distance']! < minDistance) {
        minDistance = distanceToSegment['distance']!;
        nearestPointOnLine = distanceToSegment['point'] as LatLng;
      }
    }
    
    // * Also check distance to route points (in case route has very few points)
    for (final point in _navigationRoute!) {
      final distance = _calculateDistance(tapPoint, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPointOnLine = point;
      }
    }
    
    // * Return if within reasonable distance (200 meters - more forgiving)
    if (minDistance < 0.2) {
      return nearestPointOnLine;
    }
    return null;
  }
  
  /// * Calculate distance from a point to a line segment and return the nearest point on the segment
  Map<String, dynamic> _distanceToLineSegment(LatLng point, LatLng segmentStart, LatLng segmentEnd) {
    // * Vector from segment start to end
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;
    
    // * Vector from segment start to point
    final px = point.longitude - segmentStart.longitude;
    final py = point.latitude - segmentStart.latitude;
    
    // * Calculate dot product
    final dot = dx * px + dy * py;
    final lenSq = dx * dx + dy * dy;
    
    // * Parameter t represents position along segment (0 = start, 1 = end)
    double t = 0.0;
    if (lenSq > 0) {
      t = (dot / lenSq).clamp(0.0, 1.0);
    }
    
    // * Nearest point on segment
    final nearestPoint = LatLng(
      segmentStart.latitude + t * dy,
      segmentStart.longitude + t * dx,
    );
    
    // * Distance to nearest point
    final distance = _calculateDistance(point, nearestPoint);
    
    return {
      'distance': distance,
      'point': nearestPoint,
    };
  }
  
  /// * Get minimum distance from point to route (for feedback)
  double _getMinDistanceToRoute(LatLng point) {
    if (_navigationRoute == null || _navigationRoute!.isEmpty) return double.infinity;
    
    double minDistance = double.infinity;
    
    // * Check distance to line segments
    for (int i = 0; i < _navigationRoute!.length - 1; i++) {
      final p1 = _navigationRoute![i];
      final p2 = _navigationRoute![i + 1];
      final distanceToSegment = _distanceToLineSegment(point, p1, p2);
      final segmentDistance = distanceToSegment['distance'] as double;
      if (segmentDistance < minDistance) {
        minDistance = segmentDistance;
      }
    }
    
    // * Also check distance to route points
    for (final routePoint in _navigationRoute!) {
      final distance = _calculateDistance(point, routePoint);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance;
  }
  
  /// * Calculate distance between two points in kilometers
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(p2.latitude - p1.latitude);
    final double dLon = _toRadians(p2.longitude - p1.longitude);
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(p1.latitude)) * math.cos(_toRadians(p2.latitude)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  
  /// * Recalculate route with control points - routes along actual roads (or updates geometry if GraphHopper unavailable)
  Future<void> _recalculateRouteWithControlPoints() async {
    if (_navigationRoute == null || _navigationRoute!.isEmpty) return;
    
    // * If no control points, just recalculate the original route
    if (_routeControlPoints.isEmpty) {
      if (_navigationDestination != null && _navigationMode != null) {
        try {
          await _calculateRoute(
            _navigationDestination!,
            _navigationMode!,
            origin: _currentLocation,
          );
        } catch (e) {
          // * GraphHopper unavailable - keep existing route
        }
      }
      return;
    }
    
    // * Get start and end points from the route
    final routeStart = _navigationRoute!.first;
    final routeEnd = _navigationRoute!.last;
    
    // * Determine vehicle mode (use existing or default to car)
    final mode = _navigationMode ?? 'car';
    
    // * Try to recalculate via GraphHopper to route along actual roads
    bool graphhopperSuccess = false;
    try {
      // * Use route start as origin, route end as destination, control points as waypoints
      await _calculateRoute(
        routeEnd,
        mode,
        origin: routeStart,
        waypoints: _routeControlPoints,
      );
      
      graphhopperSuccess = true;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Route updated to follow roads!"),
            duration: Duration(seconds: 2),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      // * GraphHopper unavailable - use fallback: manually adjust route geometry
      graphhopperSuccess = false;
    }
    
    // * Fallback: If GraphHopper fails, manually update route geometry to pass through control points
    if (!graphhopperSuccess) {
      _updateRouteGeometryWithControlPoints();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Route updated (GraphHopper unavailable - route may not follow roads)"),
            duration: Duration(seconds: 3),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    }
  }
  
  /// * Update route geometry to pass through control points as waypoints (fallback when GraphHopper unavailable)
  /// * Route goes: Start → Control Point 1 → Control Point 2 → ... → End
  void _updateRouteGeometryWithControlPoints() {
    if (_navigationRoute == null || _navigationRoute!.isEmpty) return;
    
    final routeStart = _navigationRoute!.first;
    final routeEnd = _navigationRoute!.last;
    
    // * If no control points, keep original route
    if (_routeControlPoints.isEmpty) {
      return;
    }
    
    // * Sort control points by their projected position along the current route.
    // * This keeps waypoints in a stable order even when the route curves.
    final currentRouteForOrdering = List<LatLng>.from(_navigationRoute!);
    double getProgressOnRoute(LatLng point) {
      if (currentRouteForOrdering.length < 2) return 0.0;
      
      double bestDistanceKm = double.infinity;
      double bestProgress = 0.0;
      
      for (int i = 0; i < currentRouteForOrdering.length - 1; i++) {
        final a = currentRouteForOrdering[i];
        final b = currentRouteForOrdering[i + 1];
        
        final dx = b.longitude - a.longitude;
        final dy = b.latitude - a.latitude;
        final px = point.longitude - a.longitude;
        final py = point.latitude - a.latitude;
        
        final lenSq = dx * dx + dy * dy;
        double t = 0.0;
        if (lenSq > 0) {
          t = ((dx * px + dy * py) / lenSq).clamp(0.0, 1.0);
        }
        
        final nearest = LatLng(
          a.latitude + t * dy,
          a.longitude + t * dx,
        );
        
        final distKm = _calculateDistance(point, nearest);
        if (distKm < bestDistanceKm) {
          bestDistanceKm = distKm;
          bestProgress = i + t;
        }
      }
      
      return bestProgress;
    }
    
    final sortedControlPoints = List<LatLng>.from(_routeControlPoints);
    sortedControlPoints.sort((a, b) {
      final progA = getProgressOnRoute(a);
      final progB = getProgressOnRoute(b);
      return progA.compareTo(progB);
    });
    
    // * Build route: Start → CP1 → CP2 → ... → End (with smooth curve generation)
    final waypoints = <LatLng>[
      routeStart,
      ...sortedControlPoints,
      routeEnd,
    ];
    
    final updatedRoute = PolylineSmoothing.catmullRomThroughWaypoints(
      waypoints,
      targetSpacingMeters: 5.0,
      minPointsPerSegment: 8,
      maxPointsPerSegment: 120,
    );
    
    // * Update distance + duration estimates to match the new geometry (useful for saving routes).
    double updatedDistanceKm = 0.0;
    for (int i = 0; i < updatedRoute.length - 1; i++) {
      updatedDistanceKm += _calculateDistance(updatedRoute[i], updatedRoute[i + 1]);
    }
    
    final mode = _navigationMode ?? "car";
    final avgSpeedKmh = () {
      switch (mode) {
        case "motorcycle_sub400":
          return 40.0;
        case "motorcycle_400plus":
          return 50.0;
        case "truck":
          return 35.0;
        case "pedestrian":
          return 5.0;
        case "car":
        default:
          return 45.0;
      }
    }();
    final estimatedMinutes =
        ((updatedDistanceKm / avgSpeedKmh) * 60).round().clamp(1, 24 * 60 * 7);
    final updatedDuration = Duration(minutes: estimatedMinutes);
    
    // * Update route immediately - force rebuild
    if (mounted) {
      setState(() {
        _navigationRoute = List<LatLng>.from(updatedRoute); // * Create new list to force update
        _routeDistance = updatedDistanceKm;
        _routeDuration = updatedDuration;
      });
    }
    
    // * Refresh traveled/upcoming segments if navigation is active.
    _updateRouteSegments();
  }
  
  /// * Calculate route with custom start and end points
  Future<void> _calculateRouteWithCustomPoints(LatLng start, LatLng end, String mode) async {
    if (!mounted) return;
    
    // * Track if GraphHopper failed
    bool graphhopperFailed = false;
    
    try {
      // * Calculate route with control points as waypoints (Start → CP1 → CP2 → ... → End)
      try {
        await _calculateRoute(
          end, 
          mode, 
          origin: start,
          waypoints: _routeControlPoints, // * Use control points as waypoints
        );
      } catch (e) {
        // * GraphHopper failed - mark it and continue with fallback route
        graphhopperFailed = true;
        debugPrint("⚠️ [MapScreen] GraphHopper unavailable, using fallback route");
      }
      
      // * Check mounted again after async operation
      if (!mounted) return;
      
      if (_availableRoutes.isNotEmpty && _selectedRouteIndex < _availableRoutes.length) {
        final route = _availableRoutes[_selectedRouteIndex];
        
        // * Validate route has points
        if (route.points.isEmpty || route.points.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Route has no points. Please try different locations."),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
          return;
        }
        
        // * If GraphHopper failed, skip preview sheet and just show route on map
        if (graphhopperFailed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Route calculated (GraphHopper unavailable). Route shown on map."),
                backgroundColor: AppTheme.infoColor,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: "Start",
                  textColor: Colors.white,
                  onPressed: () {
                    if (mounted) {
                      _beginNavigation(end, mode);
                    }
                  },
                ),
              ),
            );
          }
          return; // * Don't show preview sheet for fallback routes
        }
        
        final vehicleType = _getVehicleTypeFromMode(mode);
        final vehicleModeName = _getNavigationModeName(mode);
        
        // * Wait for next frame to ensure UI is stable and dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted || !context.mounted) return;
        
        // * Show bottom sheet with error handling
        try {
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            isDismissible: true,
            enableDrag: true,
            builder: (sheetContext) {
              // * Validate route again in builder
              if (route.points.isEmpty || route.points.length < 2) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: const Center(
                    child: Text("Invalid route data"),
                  ),
                );
              }
              
              return RoutePreviewSheet(
                route: route,
                vehicleType: vehicleType,
                vehicleModeName: vehicleModeName,
                onSaveRoute: () {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (mounted) {
                    setState(() {
                      _navigationMode = mode;
                      _navigationDestination = end;
                      _customStartPoint = start;
                      _customEndPoint = end;
                    });
                    _showSaveRouteDialog();
                  }
                },
                onStartNavigation: () {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (mounted) {
                    _beginNavigation(end, mode);
                  }
                },
                onCancel: () {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                onEditRoute: () {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (mounted) {
                    _startRouteEditing(end, mode, start);
                  }
                },
                onApplyForSticker: null,
              );
            },
          );
        } catch (e, stackTrace) {
          // * If preview sheet fails, just show snackbar - don't crash
          debugPrint("❌ [MapScreen] Error showing route preview: $e");
          debugPrint("❌ [MapScreen] Stack: $stackTrace");
          
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Route calculated. Tap 'Start' to begin navigation."),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: "Start",
                  textColor: Colors.white,
                  onPressed: () {
                    if (mounted) {
                      _beginNavigation(end, mode);
                    }
                  },
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No route found. Please try different points."),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint("❌ [MapScreen] Error calculating route: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error calculating route: ${e.toString()}"),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// * Start route drawing mode
  void _startRouteDrawing() {
    setState(() {
      _isDrawingRoute = true;
      _drawnRoutePoints = [];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tap on map to draw route. Long press to finish."),
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  /// * Handle route drawn completion
  void _onRouteDrawn(List<LatLng> points) {
    if (points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route must have at least 2 points")),
      );
      return;
    }
    
    setState(() {
      _isDrawingRoute = false;
    });
    
    // * Show save route dialog with drawn route
    _showSaveDrawnRouteDialog(points);
  }
  
  /// * Show save dialog for drawn route
  void _showSaveDrawnRouteDialog(List<LatLng> points) {
    if (!SupabaseService().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sign in to save routes"),
          action: SnackBarAction(
            label: "Sign in",
            onPressed: () {
              Navigator.of(context).pushNamed("/login");
            },
          ),
        ),
      );
      return;
    }

    final startPoint = points.first;
    final endPoint = points.last;
    
    // * Calculate approximate distance
    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += const Distance().distance(points[i], points[i + 1]);
    }
    
    showDialog(
      context: context,
      builder: (context) => SaveRouteDialog(
        routePoints: points,
        startPoint: startPoint,
        endPoint: endPoint,
        distanceMeters: totalDistance.round(),
        duration: Duration(seconds: (totalDistance / 50 * 3600).round()), // * Estimate: 50 km/h average
        vehicleType: VehicleType.car, // * Default, user can change
        onEditRoute: () {
          Navigator.pop(context); // * Close save dialog
          // * Enable editing mode for drawn route
          setState(() {
            _navigationRoute = points;
            _navigationDestination = endPoint;
            _customStartPoint = startPoint;
            _customEndPoint = endPoint;
            _navigationMode = 'car'; // * Default mode for drawn routes
            _isEditingRoute = true;
            _routeControlPoints = [];
            _draggingControlPointIndex = null;
          });
          
          // * Fit map to route
          if (points.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints(points);
            _safeFitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
              ),
            );
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Route loaded for editing. Tap on the route line to add control points. Tap a control point to move it."),
              duration: Duration(seconds: 4),
            ),
          );
        },
      ),
    );
  }
  
  /// * Show save route dialog
  void _showSaveRouteDialog() {
    if (_navigationRoute == null || _navigationRoute!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No route to save")),
      );
      return;
    }

    if (!SupabaseService().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sign in to save routes"),
          action: SnackBarAction(
            label: "Sign in",
            onPressed: () {
              Navigator.of(context).pushNamed("/login");
            },
          ),
        ),
      );
      return;
    }
    
    // * Resolve context for saving (supports route creation preview, editing mode, and active navigation).
    final routePoints = List<LatLng>.from(_navigationRoute!);
    final mode = _navigationMode ?? "car";
    final vehicleType = _getVehicleTypeFromMode(mode);
    
    // * Prefer custom start/end points only if they match the current route geometry.
    LatLng resolveStartPoint() {
      final custom = _customStartPoint;
      if (custom != null) {
        final distKm = _calculateDistance(custom, routePoints.first);
        if (distKm < 0.2) {
          return custom;
        }
      }
      return routePoints.first;
    }

    LatLng resolveEndPoint() {
      final custom = _customEndPoint;
      if (custom != null) {
        final distKm = _calculateDistance(custom, routePoints.last);
        if (distKm < 0.2) {
          return custom;
        }
      }
      return _navigationDestination ?? routePoints.last;
    }

    final startPoint = resolveStartPoint();
    final endPoint = resolveEndPoint();
    
    // * Compute distance from geometry (km → meters).
    double distanceKm = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      distanceKm += _calculateDistance(routePoints[i], routePoints[i + 1]);
    }
    final distanceMeters = (distanceKm * 1000).round();
    
    // * Use existing duration if available; otherwise estimate by profile.
    final duration = _routeDuration.inSeconds > 0 ? _routeDuration : () {
      final avgSpeedKmh = () {
        switch (mode) {
          case "motorcycle_sub400":
            return 40.0;
          case "motorcycle_400plus":
            return 50.0;
          case "truck":
            return 35.0;
          case "pedestrian":
            return 5.0;
          case "car":
          default:
            return 45.0;
        }
      }();
      final minutes = ((distanceKm / avgSpeedKmh) * 60).round().clamp(1, 24 * 60 * 7);
      return Duration(minutes: minutes);
    }();
    
    showDialog(
      context: context,
      builder: (context) => SaveRouteDialog(
        routePoints: routePoints,
        startPoint: startPoint,
        endPoint: endPoint,
        distanceMeters: distanceMeters,
        duration: duration,
        vehicleType: vehicleType,
        onEditRoute: routePoints.length >= 2
            ? () {
                Navigator.pop(context); // * Close save dialog
                _startRouteEditing(endPoint, mode, startPoint);
              }
            : null,
      ),
    );
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
      _navigationRouteSignature = null;
      _navigationRouteCumulativeMeters = null;
      _isNavigationFollowing = true;
      _isNavigationMapRotationEnabled = true;
      _lastNavigationCameraUpdateAt = null;
      _availableRoutes = [];
      _selectedRouteIndex = 0;
      _traveledRoute = [];
      _upcomingRoute = [];
      _isOffRoute = false;
      _isRerouting = false;
      _remainingDistance = 0.0;
      _remainingDuration = Duration.zero;
      _distanceIndicators = null;
      _navigationHazardWarning = null;
      _navigationHazardDistanceMeters = null;
      _navigationHazardMutedUntil.clear();
      _navigationHazardHapticAt.clear();
      _currentSpeedKph = null;
      _speedLimitResult = const SpeedLimitResult(
        speedLimitKph: null,
        source: SpeedLimitSource.unknown,
        highwayType: null,
        wayId: null,
        rawMaxspeed: null,
      );
      _isOverspeeding = false;
      _lastOverspeedHapticAt = null;
      _lastSpeedLimitUpdateAt = null;
      _lastSpeedLimitUpdateLocation = null;
      _isLoadingSpeedLimit = false;
      _lastAcceptedLocationAt = null;
      _lastAcceptedLocation = null;
    });

    // * Return to a north-up map when leaving navigation (matches Google Maps/Waze).
    _safeRotateMap(0.0);
    // * Expose navigation state to shared UI (e.g., global FAB).
    ref.read(mapIsNavigatingProvider.notifier).state = false;
    
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

  double _toDegrees(double radians) => radians * (180.0 / math.pi);

  double _normalizeDegrees(double degrees) {
    if (!degrees.isFinite) return 0.0;
    var normalized = degrees % 360.0;
    if (normalized < 0) normalized += 360.0;
    return normalized;
  }

  double _calculateBearingDegrees(LatLng start, LatLng end) {
    final lat1 = _toRadians(start.latitude);
    final lat2 = _toRadians(end.latitude);
    final dLon = _toRadians(end.longitude - start.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearingRad = math.atan2(y, x);
    return _normalizeDegrees(_toDegrees(bearingRad));
  }

  double? _estimateRouteBearingDegrees(LatLng location) {
    final route = _navigationRoute;
    if (route == null || route.length < 2) return null;

    LatLng? bestStart;
    LatLng? bestEnd;
    var bestDistance = double.infinity;

    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];

      final dx = end.longitude - start.longitude;
      final dy = end.latitude - start.latitude;
      final px = location.longitude - start.longitude;
      final py = location.latitude - start.latitude;

      final lenSq = dx * dx + dy * dy;
      var t = 0.0;
      if (lenSq > 0) {
        t = ((dx * px + dy * py) / lenSq).clamp(0.0, 1.0);
      }

      final projected = LatLng(
        start.latitude + t * dy,
        start.longitude + t * dx,
      );

      final distanceToRoute = _calculateHaversineDistance(location, projected);
      if (distanceToRoute < bestDistance) {
        bestDistance = distanceToRoute;
        bestStart = start;
        bestEnd = end;
      }
    }

    if (bestStart == null || bestEnd == null) return null;
    return _calculateBearingDegrees(bestStart, bestEnd);
  }

  double? _computeNavigationRotationDegrees(LatLng location) {
    if (!_isNavigationMapRotationEnabled) return null;

    final heading = _currentHeadingDegrees;
    final headingIsValid = heading != null &&
        heading.isFinite &&
        heading >= 0 &&
        heading <= 360;
    if (headingIsValid) {
      return _normalizeDegrees(heading);
    }

    // * Fallback: rotate based on route direction if heading is unavailable (common on web).
    return _estimateRouteBearingDegrees(location);
  }

  void _updateNavigationCamera(LatLng location, {bool force = false}) {
    if (!_isNavigating || !_isNavigationFollowing) return;
    if (!_isMapReady) return;

    final now = DateTime.now();
    if (!force && _lastNavigationCameraUpdateAt != null) {
      final since = now.difference(_lastNavigationCameraUpdateAt!);
      if (since < _navigationCameraThrottle) {
        return;
      }
    }
    _lastNavigationCameraUpdateAt = now;

    // * Use a zoomed-in default when (re)centering, otherwise respect current zoom.
    final desiredZoom = (force ? _navigationFollowZoom : _mapZoom).clamp(
      AppConstants.minZoom,
      AppConstants.maxZoom,
    );

    final rotation = _computeNavigationRotationDegrees(location);
    if (rotation != null) {
      _safeMoveAndRotateMap(location, desiredZoom, rotation);
      return;
    }

    // * No rotation (north-up)
    _safeMoveMap(location, desiredZoom);
  }

  void _recenterNavigationCamera() {
    if (!_hasPreciseLocation) {
      _requestLocationPermission();
      return;
    }

    if (mounted) {
      setState(() {
        _isNavigationFollowing = true;
      });
    }
    _updateNavigationCamera(_currentLocation, force: true);
  }

  Future<void> _updateSpeedLimitIfNeeded({
    required LatLng location,
    required NavigationSettings settings,
  }) async {
    if (!_isNavigating) return;
    if (!settings.showSpeedHud) return;
    if (_isLoadingSpeedLimit) return;

    final now = DateTime.now();
    if (_lastSpeedLimitUpdateAt != null &&
        now.difference(_lastSpeedLimitUpdateAt!).inSeconds < 6) {
      return;
    }

    if (_lastSpeedLimitUpdateLocation != null) {
      final movedMeters = _calculateHaversineDistance(location, _lastSpeedLimitUpdateLocation!);
      if (movedMeters < 120) {
        return;
      }
    }

    _isLoadingSpeedLimit = true;
    _lastSpeedLimitUpdateAt = now;
    _lastSpeedLimitUpdateLocation = location;

    try {
      final result = await _speedLimitService.getSpeedLimit(
        location: location,
        settings: settings,
      );
      if (!mounted) return;
      setState(() {
        _speedLimitResult = result;
      });
    } finally {
      _isLoadingSpeedLimit = false;
    }
  }

  bool _computeIsOverspeeding({
    required double? speedKph,
    required SpeedLimitResult limit,
    required NavigationSettings settings,
  }) {
    if (!settings.overspeedWarningsEnabled) return false;
    if (speedKph == null || !speedKph.isFinite) return false;
    final limitKph = limit.speedLimitKph;
    if (limitKph == null || limitKph <= 0) return false;
    final threshold = limitKph + settings.overspeedToleranceKph;
    return speedKph > threshold;
  }

  void _maybeTriggerOverspeedHaptic(bool isOverspeeding) {
    if (!isOverspeeding) return;
    final now = DateTime.now();
    final last = _lastOverspeedHapticAt;
    if (last != null && now.difference(last).inSeconds < 12) {
      return;
    }
    _lastOverspeedHapticAt = now;
    HapticFeedback.mediumImpact();
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * clamped,
      a.longitude + (b.longitude - a.longitude) * clamped,
    );
  }

  _StableLocationResult _stabilizeLocationUpdate({
    required LatLng current,
    required LatLng candidate,
    required DateTime now,
    required bool hasAcceptedBefore,
    required bool isNavigating,
    required double? accuracyMeters,
  }) {
    // * Reject clearly invalid coordinates.
    if (!candidate.latitude.isFinite ||
        !candidate.longitude.isFinite ||
        candidate.latitude.abs() > 90 ||
        candidate.longitude.abs() > 180) {
      return _StableLocationResult(location: current, accepted: false);
    }

    // * If the browser reports extremely poor accuracy, don't jump the marker.
    final acc = accuracyMeters;
    if (acc != null && acc.isFinite && acc > 2000) {
      return _StableLocationResult(location: current, accepted: false);
    }

    // * Filter huge jumps that happen too fast (common in Web geolocation).
    if (hasAcceptedBefore) {
      final distanceMeters = _calculateHaversineDistance(current, candidate);
      final lastAt = _lastAcceptedLocationAt;
      if (lastAt != null) {
        final dtSeconds = now.difference(lastAt).inSeconds.clamp(1, 3600);

        // * Anything > 1.5km in < 10s is almost certainly a GPS glitch.
        if (dtSeconds <= 10 && distanceMeters > 1500) {
          return _StableLocationResult(location: current, accepted: false);
        }

        // * Anything > 8km in < 60s is also suspicious.
        if (dtSeconds <= 60 && distanceMeters > 8000) {
          return _StableLocationResult(location: current, accepted: false);
        }
      }
    }

    // * Smooth small jitter. During navigation we keep it more responsive.
    final alpha = isNavigating ? 0.35 : 0.20;
    final next = hasAcceptedBefore ? _lerpLatLng(current, candidate, alpha) : candidate;
    return _StableLocationResult(location: next, accepted: true);
  }
  
  /// * Open directions options
  Future<void> _openDirections(LatLng destination) async {
    try {
      if (mounted) {
        // * Do NOT auto-pop here.
        // ! The caller is responsible for closing any currently open sheet.
        // * Auto-popping can accidentally pop the MapScreen route, breaking navigation.
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
      // * Use a simple mock result for now (can enhance with reverse geocoding later)
      final mockResult = {
        'display_name': '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'address': null,
      };
      
      // * Move map to location
      _safeMoveMap(point, 15.0);
      
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
    // * Removed verbose logging to prevent console overflow
    
    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        final rawUpdated = LatLng(position.latitude, position.longitude);
        final heading = position.heading;
        final headingIsValid = heading.isFinite && heading >= 0 && heading <= 360;
        if (!mounted) return;

        final now = DateTime.now();
        final stable = _stabilizeLocationUpdate(
          current: _currentLocation,
          candidate: rawUpdated,
          now: now,
          hasAcceptedBefore: _lastAcceptedLocation != null,
          isNavigating: _isNavigating,
          accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
        );
        final updated = stable.location;
        if (stable.accepted) {
          _lastAcceptedLocationAt = now;
          _lastAcceptedLocation = updated;
        }
        
        setState(() {
          _currentLocation = updated;
          _hasPreciseLocation = true;
          _currentHeadingDegrees = headingIsValid ? heading : _currentHeadingDegrees;
        });
        
        // * Detect country code when location is updated (only once per significant move)
        _detectCountryCode();
        
        if (_isNavigating) {
          // * Update route segments based on current position
          _updateRouteSegments();
          
          // * Update distance indicators
          final indicators = _distanceTracker.getDistanceIndicators(updated);
          final hazards = ref.read(mapHazardsProvider);
          final navigationSettings = ref.read(navigationSettingsProvider);
          final hazardWarning = _computeUpcomingHazardWarning(
            currentLocation: updated,
            hazards: hazards,
          );

          final speedKph = position.speed.isFinite ? (position.speed * 3.6) : null;

          setState(() {
            _distanceIndicators = indicators;
            _navigationHazardWarning = hazardWarning?.hazard;
            _navigationHazardDistanceMeters = hazardWarning?.distanceAheadMeters;
            _currentSpeedKph = speedKph;
          });

          // * Update speed limit in the background (best-effort).
          _updateSpeedLimitIfNeeded(location: updated, settings: navigationSettings);

          final isOverspeeding = _computeIsOverspeeding(
            speedKph: speedKph,
            limit: _speedLimitResult,
            settings: navigationSettings,
          );
          if (mounted) {
            setState(() {
              _isOverspeeding = isOverspeeding;
            });
          }
          _maybeTriggerOverspeedHaptic(isOverspeeding);

          if (hazardWarning != null && hazardWarning.shouldHaptic) {
            // * Keep haptics subtle and throttled (safety-first)
            HapticFeedback.lightImpact();
          }
          
          // * Check if user is off-route
          final isOffRoute = _checkOffRoute(updated);
          
          // * Trigger rerouting if off-route
          if (isOffRoute && !_isRerouting) {
            _recalculateRouteFromCurrentPosition();
          }
          
          // * During navigation, keep the camera following unless the user manually panned/zoomed.
          if (_isNavigationFollowing) {
            _updateNavigationCamera(updated);
          }
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
    
    // * Removed verbose logging to prevent console overflow
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
          _safeMoveMap(location, AppConstants.defaultZoom);
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
              _safeMoveMap(location, _mapZoom);
              debugPrint("📍 [MapScreen] Map moved to fresh location");
            } catch (e) {
              debugPrint("❌ [MapScreen] Error moving map: $e");
            }
          }
          // * Removed verbose logging to prevent console overflow
          // * Detect country code when location is updated
          _detectCountryCode();
        } else {
          debugPrint("⚠️ [MapScreen] Could not get fresh location, using last known or default");
          if (lastKnown == null && mounted) {
            // * Only use default if we have no location at all
            _safeMoveMap(_currentLocation, AppConstants.defaultZoom);
          }
        }
      } catch (e) {
        debugPrint("❌ [MapScreen] Error getting fresh location: $e");
        if (lastKnown == null && mounted) {
          _safeMoveMap(_currentLocation, AppConstants.defaultZoom);
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
        _safeMoveMap(location, AppConstants.defaultZoom);
        
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
    // * Removed verbose logging to prevent console overflow
    try {
    // * Load all hazards initially (will be optimized with PostGIS RPC later)
    // * For now, load a reasonable bounding box around current location
    const offset = 0.1; // * Roughly 10km
      
      if (!mounted) {
        debugPrint("❌ [MapScreen] Widget not mounted, skipping _onMapReady");
        return;
      }
      
      // * Removed verbose logging to prevent console overflow
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
      // * Removed verbose logging to prevent console overflow
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
      
      // * Removed verbose logging to prevent console overflow
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
      _scheduleDynamicPoiRefresh();
      // * Removed verbose logging to prevent console overflow
    } catch (e, stackTrace) {
      debugPrint("❌ [MapScreen] ERROR in _onMapMoved: $e");
      debugPrint("❌ [MapScreen] Stack: $stackTrace");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // * Removed verbose build logging to prevent console overflow
    
    // * Don't build map until initialized
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }
    
    // * Removed verbose build logging to prevent console overflow
    
    // * Watch for route editing - load route when set
    final routeToEdit = ref.watch(routeEditingProvider);
    if (routeToEdit != null) {
      // * Load route for editing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadRouteForEditing(routeToEdit);
          // * Clear the provider after loading
          ref.read(routeEditingProvider.notifier).state = null;
        }
      });
    }
    
    // * Wrap everything in error boundary
    try {
      // * Cache the notifier for use in callbacks - with error handling
      if (_hazardsNotifier == null) {
        try {
          // * Removed verbose logging to prevent console overflow
          _hazardsNotifier = ref.read(mapHazardsProvider.notifier);
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
      }
      
      // * Safely get hazards - ensure it's never null
      List<Hazard> hazards;
      try {
        // * Removed verbose logging to prevent console overflow
        hazards = ref.watch(mapHazardsProvider);
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
      final navigationSettings = ref.watch(navigationSettingsProvider);
      final mapZoom = _mapZoom;
      final showKnownPlaces = !_isNavigating && mapZoom >= _knownPlacesMinZoom;
      final showDynamicPois = !_isNavigating && mapZoom >= _dynamicPoisMinZoom;
      final showHazardMarkers = mapZoom >= _knownPlacesMinZoom;
      final showHoaMarkers = !_isNavigating && mapZoom >= 13.0;
    
    // * Listen to route creation trigger
    ref.listen<RouteCreationAction?>(routeCreationTriggerProvider, (previous, next) {
      if (next != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (next == RouteCreationAction.showDialog) {
              _showRouteCreationDialog();
            } else if (next == RouteCreationAction.startDrawing) {
              _startRouteDrawing();
            } else if (next == RouteCreationAction.useNavigation) {
              _showNavigationWithCustomPointsDialog();
            }
            // * Reset trigger
            ref.read(routeCreationTriggerProvider.notifier).state = null;
          }
        });
      }
    });
    
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
                onMapReady: () {
                  // * Wrap in try-catch to prevent crashes
                  if (mounted) {
                    try {
                      _handleFlutterMapReady();
                    } catch (e) {
                      debugPrint("Error in onMapReady: $e");
                    }
                  }
                },
              onMapEvent: (event) {
                  final camera = event.camera;
                  final nextZoom = camera.zoom;
                  final nextCenter = camera.center;
                  final nextRotation = camera.rotation;
                  final nextBounds = camera.visibleBounds;

                  // * Cache camera state for non-build logic (e.g., navigation following)
                  _mapZoom = nextZoom;
                  _mapCenter = nextCenter;
                  _mapRotationDegrees = nextRotation;
                  _mapVisibleBounds = nextBounds;

                  // * If the user manually pans/zooms/rotates during navigation, stop auto-follow.
                  if (_isNavigating && _isNavigationFollowing) {
                    final shouldDisableFollow =
                        (event is MapEventMoveStart && event.source == MapEventSource.dragStart) ||
                        (event is MapEventRotateStart &&
                            event.source != MapEventSource.mapController);
                    if (shouldDisableFollow && mounted) {
                      setState(() {
                        _isNavigationFollowing = false;
                      });
                    }
                  }

                  // * Only rebuild on move end to update zoom-based UI/marker visibility
                  if (event is MapEventMoveEnd) {
                    if (mounted) {
                      setState(() {
                        _mapZoom = nextZoom;
                        _mapCenter = nextCenter;
                        _mapRotationDegrees = nextRotation;
                        _mapVisibleBounds = nextBounds;
                      });
                    }
                    try {
                      _onMapMoved();
                    } catch (e, stackTrace) {
                      debugPrint("❌ [MapScreen] Error in onMapMoved callback: $e");
                      debugPrint("❌ [MapScreen] Stack: $stackTrace");
                    }
                  }
              },
              onTap: (tapPosition, point) {
                  // * Handle custom point selection for navigation
                  // * Also check if we have points set but state was lost (e.g., after minimizing)
                  if (_isSelectingCustomPoints || (_customStartPoint != null && _customEndPoint == null)) {
                    // * Restore state if it was lost
                    if (!_isSelectingCustomPoints) {
                      setState(() {
                        _isSelectingCustomPoints = true;
                        _selectingStartPoint = false; // * We have start, so selecting end
                      });
                    }
                    
                    final wasSelectingStart = _selectingStartPoint; // * Remember before state change
                    final bool justSetEndPoint = !_selectingStartPoint && _customEndPoint == null;
                    
                    setState(() {
                      if (_selectingStartPoint) {
                        _customStartPoint = point;
                        _selectingStartPoint = false; // * Switch to selecting end point
                      } else {
                        _customEndPoint = point;
                      }
                      // * Ensure state is maintained
                      _isSelectingCustomPoints = true;
                    });
                    
                    // * Auto-calculate route when end point is selected (after setState)
                    // * Close dialog first, then calculate route
                    if (justSetEndPoint && _customStartPoint != null && _customEndPoint != null) {
                      // * Close any open dialogs/sheets first
                      if (mounted) {
                        try {
                          // * Try to close modal bottom sheet if open
                          final navigator = Navigator.of(context, rootNavigator: false);
                          if (navigator.canPop()) {
                            navigator.pop();
                          }
                        } catch (e) {
                          // * Ignore if dialog already closed
                        }
                      }
                      
                      // * Wait a moment for dialog to close, then calculate route
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted && _customStartPoint != null && _customEndPoint != null) {
                          setState(() {
                            _isSelectingCustomPoints = false;
                          });
                          _calculateRouteWithCustomPoints(_customStartPoint!, _customEndPoint!, 'car');
                        }
                      });
                    }
                    
                    // * Only show feedback if we didn't auto-calculate
                    if (_selectingStartPoint || _customEndPoint == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            wasSelectingStart
                                ? "Start point selected! Now tap on map to select END point."
                                : "End point selected! Calculating route...",
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                    
                    // * Reopen/expand the bottom sheet to show updated state (only if it was closed)
                    // * Check if there's already a bottom sheet open by trying to find it
                    if (_customEndPoint == null) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted && _isSelectingCustomPoints) {
                          // * Only reopen if we don't have both points yet
                          if (_customStartPoint == null || _customEndPoint == null) {
                            _showNavigationWithCustomPointsDialog();
                          }
                        }
                      });
                    }
                    return;
                  }
                  
                  // * Handle route path editing mode - check if tapping near a control point to move it
                  // * IMPORTANT: Check control points FIRST before checking route line
                  if (_isEditingRoute && _routeControlPoints.isNotEmpty) {
                    // * Check if tap is near any control point (within 100 meters - more forgiving)
                    int nearestIndex = -1;
                    double minDistance = double.infinity;
                    
                    for (int i = 0; i < _routeControlPoints.length; i++) {
                      final distance = _calculateDistance(point, _routeControlPoints[i]);
                      if (distance < minDistance) {
                        minDistance = distance;
                        nearestIndex = i;
                      }
                    }
                    
                    // * If within 100 meters of a control point, move it
                    if (nearestIndex >= 0 && minDistance < 0.1) { // * 100 meters
                      // * Move control point to tap location
                      setState(() {
                        _routeControlPoints[nearestIndex] = point;
                      });
                      
                      // * Update route immediately (synchronous for instant visual feedback)
                      if (_navigationRoute != null && _navigationRoute!.isNotEmpty) {
                        _updateRouteGeometryWithControlPoints();
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Control point moved. Route updated."),
                              duration: Duration(seconds: 1),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      }
                      return; // * IMPORTANT: Return here to prevent adding new control point
                    }
                  }
                  
                  // * Handle route path editing mode - tap on route line to add control point
                  if (_isEditingRoute && _navigationRoute != null && _navigationRoute!.isNotEmpty) {
                    // * Find nearest point on route line
                    final nearestPoint = _findNearestRoutePoint(point);
                    if (nearestPoint != null) {
                      // * Add control point at this location
                      setState(() {
                        _routeControlPoints.add(nearestPoint);
                      });
                      
                      // * Update route immediately to show the bend
                      if (_navigationRoute != null && _navigationRoute!.isNotEmpty) {
                        _updateRouteGeometryWithControlPoints();
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Control point added (${_routeControlPoints.length} total). Route updated.",
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    } else {
                      // * Show helpful message with distance info
                      final minDist = _getMinDistanceToRoute(point);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            minDist < 0.5 
                                ? "Tap closer to the route line (${(minDist * 1000).toStringAsFixed(0)}m away)"
                                : "Tap on the purple route line to add a control point",
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                    }
                    return;
                  }
                  
                  // * Handle route drawing mode
                  if (_isDrawingRoute) {
                    setState(() {
                      _drawnRoutePoints.add(point);
                    });
                    return;
                  }
                  
                  // * Close detail sheet and search results if tapping map
                  if (mounted) {
                    try {
                      setState(() {
                        _selectedHazard = null;
                        _selectedPlace = null;
                        _showSearchResults = false;
                        _searchFocusNode.unfocus();
                      });
                    } catch (e) {
                      debugPrint("Error in onTap: $e");
                    }
                  }
              },
              onLongPress: (tapPosition, point) {
                  // * Handle route drawing finish
                  if (_isDrawingRoute) {
                    if (_drawnRoutePoints.length >= 2) {
                      _onRouteDrawn(_drawnRoutePoints);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please draw at least 2 points")),
                      );
                    }
                    return;
                  }
                  
                  // * Handle route editing - long press on route line to add control point
                  if (_isEditingRoute && _navigationRoute != null && _navigationRoute!.isNotEmpty) {
                    final nearestPoint = _findNearestRoutePoint(point);
                    if (nearestPoint != null) {
                      setState(() {
                        _routeControlPoints.add(nearestPoint);
                      });
                      
                      // * Update route immediately to show the bend
                      if (_navigationRoute != null && _navigationRoute!.isNotEmpty) {
                        _updateRouteGeometryWithControlPoints();
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Control point added (${_routeControlPoints.length} total). Route updated.",
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                      return;
                    }
                  }
                  
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
              // * Drawn route polyline (when drawing)
              if (_isDrawingRoute && _drawnRoutePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _drawnRoutePoints,
                      strokeWidth: 4.0,
                      color: AppTheme.primaryColor,
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                    ),
                  ],
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
                        strokeWidth: _isEditingRoute ? 8.0 : 6.0, // * Thicker when editing
                        color: _isEditingRoute 
                            ? AppTheme.primaryColor.withOpacity(0.9) // * More visible when editing
                            : _getRouteColor(_navigationMode ?? 'car'),
                        borderStrokeWidth: _isEditingRoute ? 3.0 : 2.0,
                        borderColor: _isEditingRoute 
                            ? Colors.white.withOpacity(0.9) // * More visible border when editing
                            : Colors.white.withOpacity(0.8),
                      ),
                    ],
                  ),
              // * Custom start/end point markers (when selecting) - Always show if points are set
              if (_isSelectingCustomPoints || _customStartPoint != null || _customEndPoint != null) ...[
                if (_customStartPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _customStartPoint!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: AppTheme.shadowMedium,
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                if (_customEndPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _customEndPoint!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: AppTheme.shadowMedium,
                          ),
                          child: const Icon(Icons.flag, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
              ],
              // * Draggable route control points (when editing route)
              if (_isEditingRoute && _routeControlPoints.isNotEmpty)
                MarkerLayer(
                  markers: _routeControlPoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controlPoint = entry.value;
                    return Marker(
                      point: controlPoint,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _draggingControlPointIndex == index 
                              ? AppTheme.primaryColor 
                              : AppTheme.warningColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: AppTheme.shadowMedium,
                        ),
                        child: const Icon(
                          Icons.drag_handle,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }).toList(),
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
                      width: 40,
                      height: 40,
                      child: UserLocationMarker(
                        headingDegrees: _currentHeadingDegrees,
                        mapRotationDegrees: _mapRotationDegrees,
                        avatarIcon: navigationSettings.avatarStyle.icon,
                      ),
                    ),
                  ],
                ),
              // * Known place markers (famous / known locations)
              // * Hide during active navigation to reduce distraction.
              if (_knownPlaces.isNotEmpty && showKnownPlaces)
                MarkerLayer(
                  markers: _filterOverlappingMarkers<Place>(
                    markers: _knownPlaces,
                    getLocation: (p) => p.location,
                    getWidth: (p) {
                      final showLabel = mapZoom >= 12.0 || _selectedPlace?.id == p.id;
                      return showLabel ? 200.0 : 40.0;
                    },
                    minPixelSpacing: 60.0, // * Minimum 60px spacing between known place markers
                    zoom: mapZoom,
                  ).map((place) {
                    final category = place.category?.toLowerCase();
                    final icon = switch (category) {
                      "mall" => Icons.storefront_outlined,
                      "terminal" => Icons.directions_bus_filled,
                      _ => Icons.place_outlined,
                    };
                    final accentColor = switch (category) {
                      "mall" => AppTheme.primaryColor,
                      "terminal" => AppTheme.infoColor,
                      _ => AppTheme.secondaryColor,
                    };
                    final showLabel = mapZoom >= 12.0 || _selectedPlace?.id == place.id; // * Show labels earlier (was 14.0)
                    final markerWidth = showLabel ? 200.0 : 40.0;
                    final markerAlignment = Marker.computePixelAlignment(
                      width: markerWidth,
                      height: _poiMarkerHeight,
                      left: _poiMarkerAnchorLeft,
                      top: _poiMarkerAnchorTop,
                    );

                    return Marker(
                      point: place.location,
                      width: markerWidth,
                      height: _poiMarkerHeight,
                      alignment: markerAlignment,
                      child: MapPoiMarker(
                        icon: icon,
                        accentColor: accentColor,
                        label: place.name,
                        showLabel: showLabel,
                        onTap: () {
                          if (!mounted) return;
                          setState(() {
                            _selectedPlace = place;
                            _selectedHazard = null;
                            _showSearchResults = false;
                          });
                          _searchFocusNode.unfocus();
                        },
                      ),
                    );
                  }).toList(),
                ),
              // * Dynamic POIs (Google Maps-like landmarks) - only show when zoomed in.
              if (showDynamicPois && _dynamicPois.isNotEmpty)
                MarkerLayer(
                  markers: () {
                    // * Filter overlapping markers, preserving original index for label visibility
                    final filtered = _filterOverlappingMarkers<MapPoi>(
                      markers: _dynamicPois,
                      getLocation: (p) => p.location,
                      getWidth: (p) {
                        final originalIndex = _dynamicPois.indexOf(p);
                        final showLabel = mapZoom >= 15.0 && originalIndex < 15;
                        return showLabel ? 200.0 : 40.0;
                      },
                      minPixelSpacing: 50.0, // * Minimum 50px spacing between dynamic POI markers
                      zoom: mapZoom,
                    );
                    return filtered;
                  }().asMap().entries.map((entry) {
                    final poi = entry.value;
                    final originalIndex = _dynamicPois.indexOf(poi); // * Get original index for label logic
                    final type = (poi.type ?? "").toLowerCase();
                    final icon = () {
                      if (type.contains("mall") || type == "retail") {
                        return Icons.storefront_outlined;
                      }
                      if (type.contains("bus") || type.contains("station") || type.contains("terminal")) {
                        return Icons.directions_bus_filled;
                      }
                      if (type.contains("hospital") || type.contains("clinic")) {
                        return Icons.local_hospital_outlined;
                      }
                      if (type.contains("school") || type.contains("university") || type.contains("college")) {
                        return Icons.school_outlined;
                      }
                      if (type.contains("fuel") || type.contains("gas") || type.contains("petrol")) {
                        return Icons.local_gas_station_outlined;
                      }
                      return Icons.place_outlined;
                    }();

                    final accentColor = () {
                      if (type.contains("mall") || type == "retail") {
                        return AppTheme.primaryColor;
                      }
                      if (type.contains("bus") || type.contains("station") || type.contains("terminal")) {
                        return AppTheme.infoColor;
                      }
                      if (type.contains("hospital") || type.contains("clinic")) {
                        return AppTheme.errorColor;
                      }
                      if (type.contains("school") || type.contains("university") || type.contains("college")) {
                        return AppTheme.secondaryColor;
                      }
                      if (type.contains("fuel") || type.contains("gas") || type.contains("petrol")) {
                        return AppTheme.warningColor;
                      }
                      return AppTheme.textSecondary;
                    }();

                    // * Show labels only when very zoomed in (and only for the most prominent POIs).
                    final showLabel = mapZoom >= 15.0 && originalIndex < 15; // * Use original index for label logic
                    final markerWidth = showLabel ? 200.0 : 40.0;
                    final markerAlignment = Marker.computePixelAlignment(
                      width: markerWidth,
                      height: _poiMarkerHeight,
                      left: _poiMarkerAnchorLeft,
                      top: _poiMarkerAnchorTop,
                    );

                    return Marker(
                      point: poi.location,
                      width: markerWidth,
                      height: _poiMarkerHeight,
                      alignment: markerAlignment,
                      child: MapPoiMarker(
                        icon: icon,
                        accentColor: accentColor,
                        label: poi.name,
                        showLabel: showLabel,
                        onTap: () {
                          if (!mounted) return;
                          final communityPlace = Place(
                            id: poi.id, // * Nominatim-backed id (`nominatim:<place_id>`)
                            name: poi.name,
                            latitude: poi.latitude,
                            longitude: poi.longitude,
                            category: (poi.type ?? poi.category)?.trim(),
                            aliases: const [],
                          );
                          setState(() {
                            // * Show the same place preview UI for dynamic POIs so users
                            // * can upload moderated photos / comment / like (Waze-style).
                            _selectedPlace = communityPlace;
                            _selectedHazard = null;
                            _showSearchResults = false;
                          });
                          _searchFocusNode.unfocus();
                        },
                      ),
                    );
                  }).toList(),
                ),
              // * Hazard markers
              if (showHazardMarkers)
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
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () {
                          if (mounted) {
                          setState(() {
                            _selectedHazard = hazard;
                            _selectedPlace = null;
                          });
                          }
                        },
                        child: HazardMarker(hazard: hazard),
                      ),
                    );
                  }).toList(),
                ),
              // * HOA Gate markers
              if (showHoaMarkers) _buildHOAMarkers(),
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
                      final currentZoom = _mapZoom;
                      final currentCenter = _mapCenter;
                      _safeMoveMap(
                        currentCenter,
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
                      final currentZoom = _mapZoom;
                      final currentCenter = _mapCenter;
                      _safeMoveMap(
                        currentCenter,
                        (currentZoom - 1).clamp(AppConstants.minZoom, AppConstants.maxZoom),
                      );
                    },
                    tooltip: "Zoom out",
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * Location Button
                  _MapControlButton(
                    icon: _isNavigating
                        ? (_isNavigationFollowing ? Icons.navigation : Icons.my_location)
                        : Icons.gps_fixed,
                    onPressed: _hasPreciseLocation
                        ? () {
                            if (_isNavigating) {
                              // * Re-center and resume follow mode.
                              _recenterNavigationCamera();
                              return;
                            }

                            // * Center on current location
                            _safeMoveMap(_currentLocation, AppConstants.defaultZoom);
                          }
                        : _requestLocationPermission,
                    tooltip: _hasPreciseLocation
                        ? (_isNavigating
                            ? (_isNavigationFollowing ? "Following route" : "Re-center")
                            : "Center on my location")
                        : "Get my location",
                    backgroundColor: _hasPreciseLocation
                        ? (_isNavigating && !_isNavigationFollowing
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor)
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
                  onSaveRoute: _showSaveRouteDialog,
                  remainingDistance: _remainingDistance > 0 ? _remainingDistance / 1000 : null,
                  remainingDuration: _remainingDuration,
                  isOffRoute: _isOffRoute,
                ),
              ),
              // * Speed HUD (Waze/Google Maps-like)
              Positioned(
                top: AppTheme.spacingMD,
                left: AppTheme.spacingMD,
                child: Builder(
                  builder: (context) {
                    final settings = ref.watch(navigationSettingsProvider);
                    if (!settings.showSpeedHud) {
                      return const SizedBox.shrink();
                    }

                    return NavigationSpeedHud(
                      speedKph: _currentSpeedKph,
                      speedLimit: _speedLimitResult,
                      isOverspeeding: _isOverspeeding,
                      onTapLimit: () {
                        // * TODO: Add per-road override UI (wayId-based) in a follow-up.
                      },
                    );
                  },
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
              // * Hazard warning banner (Waze-style)
              if (_navigationHazardWarning != null &&
                  _navigationHazardDistanceMeters != null)
                Positioned(
                  top: (_distanceIndicators != null && _distanceIndicators!.hasAny)
                      ? 170
                      : 120,
                  left: AppTheme.spacingMD,
                  right: AppTheme.spacingMD,
                  child: NavigationHazardWarningBanner(
                    hazard: _navigationHazardWarning!,
                    distanceMeters: _navigationHazardDistanceMeters!,
                    onDismiss: () {
                      if (!mounted || _navigationHazardWarning == null) return;
                      final hazardId = _navigationHazardWarning!.id;
                      setState(() {
                        // * Mute this hazard briefly to prevent immediate re-appearance.
                        _navigationHazardMutedUntil[hazardId] =
                            DateTime.now().add(const Duration(minutes: 5));
                        _navigationHazardWarning = null;
                        _navigationHazardDistanceMeters = null;
                      });
                    },
                    onTap: () {
                      if (!mounted || _navigationHazardWarning == null) return;
                      setState(() {
                        _selectedHazard = _navigationHazardWarning;
                        _selectedPlace = null;
                      });
                    },
                  ),
                ),
            ],
            // * Hazard detail bottom sheet
            if (_selectedPlace != null && !_isNavigating)
              Align(
                alignment: Alignment.bottomCenter,
                child: PlaceDetailSheet(
                  place: _selectedPlace!,
                  onGetDirections: () {
                    final destination = _selectedPlace!.location;
                    if (mounted) {
                      setState(() => _selectedPlace = null);
                    }
                    _openDirections(destination);
                  },
                  onClose: () {
                    if (mounted) {
                      setState(() => _selectedPlace = null);
                    }
                  },
                ),
              ),
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
          // * Floating button to reopen minimized sheet
          if (_showSheetReopenButton && _isSelectingCustomPoints)
            Positioned(
              bottom: 180, // * Above weather controls and bottom navigation
              right: AppTheme.spacingMD,
              child: FloatingActionButton(
                heroTag: "reopen_sheet_fab",
                onPressed: () {
                  setState(() {
                    _showSheetReopenButton = false;
                  });
                  _showNavigationWithCustomPointsDialog();
                },
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.visibility, color: Colors.white),
                tooltip: "Show selection sheet",
              ),
            ),
          // * Route editing controls - Improved UI
          if (_isEditingRoute)
            Positioned(
              bottom: 100, // * Above bottom navigation
              left: AppTheme.spacingMD,
              right: AppTheme.spacingMD,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // * Instruction text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Tap on the route line to add control points",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // * Control buttons
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_routeControlPoints.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _recalculateRouteWithControlPoints,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text("Recalculate"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _routeControlPoints.clear();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Control points cleared")),
                                    );
                                  },
                                  icon: const Icon(Icons.clear_all, size: 18),
                                  label: const Text("Clear"),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          if (_routeControlPoints.isNotEmpty) const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showSaveRouteDialog,
                                  icon: const Icon(Icons.save, size: 18),
                                  label: const Text("Save"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isEditingRoute = false;
                                      _routeControlPoints = [];
                                      _draggingControlPointIndex = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Route editing mode disabled")),
                                    );
                                  },
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text("Done"),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
              width: 34,
              height: 34,
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
      final distance = _distanceToLineSegmentSimple(point, segmentStart, segmentEnd);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance; // * Returns in meters
  }
  
  /// * Calculate distance to line segment (simplified version - uses closest endpoint)
  double _distanceToLineSegmentSimple(LatLng point, LatLng lineStart, LatLng lineEnd) {
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

  String _buildRouteSignature(List<LatLng> route) {
    if (route.isEmpty) return "0";
    final first = route.first;
    final last = route.last;
    return "${route.length}:"
        "${first.latitude.toStringAsFixed(5)},${first.longitude.toStringAsFixed(5)}:"
        "${last.latitude.toStringAsFixed(5)},${last.longitude.toStringAsFixed(5)}";
  }

  List<double> _buildRouteCumulativeMeters(List<LatLng> route) {
    if (route.isEmpty) return const [];
    final cumulative = <double>[0.0];
    var total = 0.0;
    for (int i = 1; i < route.length; i++) {
      total += _calculateHaversineDistance(route[i - 1], route[i]);
      cumulative.add(total);
    }
    return cumulative;
  }

  void _ensureNavigationRouteCache() {
    final route = _navigationRoute;
    if (route == null || route.length < 2) {
      _navigationRouteSignature = null;
      _navigationRouteCumulativeMeters = null;
      return;
    }

    final signature = _buildRouteSignature(route);
    if (_navigationRouteSignature == signature &&
        _navigationRouteCumulativeMeters != null &&
        _navigationRouteCumulativeMeters!.length == route.length) {
      return;
    }

    _navigationRouteSignature = signature;
    _navigationRouteCumulativeMeters = _buildRouteCumulativeMeters(route);
  }

  Map<String, double>? _projectPointOntoRouteMeters({
    required LatLng point,
    required List<LatLng> route,
    required List<double> cumulativeMeters,
  }) {
    if (route.length < 2 || cumulativeMeters.length != route.length) {
      return null;
    }

    var bestDistance = double.infinity;
    var bestAlong = 0.0;

    for (int i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];

      final dx = end.longitude - start.longitude;
      final dy = end.latitude - start.latitude;
      final px = point.longitude - start.longitude;
      final py = point.latitude - start.latitude;

      final lenSq = dx * dx + dy * dy;
      var t = 0.0;
      if (lenSq > 0) {
        t = ((dx * px + dy * py) / lenSq).clamp(0.0, 1.0);
      }

      final projected = LatLng(
        start.latitude + t * dy,
        start.longitude + t * dx,
      );

      final distanceToRoute = _calculateHaversineDistance(point, projected);
      if (distanceToRoute < bestDistance) {
        bestDistance = distanceToRoute;
        final segmentMeters = _calculateHaversineDistance(start, end);
        bestAlong = cumulativeMeters[i] + (segmentMeters * t);
      }
    }

    return {
      "along": bestAlong,
      "distance": bestDistance,
    };
  }

  double _hazardWarningRangeMeters(Hazard hazard) {
    final base = switch (hazard.severity) {
      SeverityLevel.low => 250.0,
      SeverityLevel.medium => 420.0,
      SeverityLevel.high => 700.0,
    };

    switch (hazard.type) {
      case HazardType.closure:
      case HazardType.roadblock:
        return base + 350.0;
      case HazardType.accident:
        return base + 200.0;
      case HazardType.flood:
      case HazardType.landslide:
        return base + 250.0;
      case HazardType.pothole:
        return base;
    }
  }

  bool _isHazardMuted(String hazardId) {
    final until = _navigationHazardMutedUntil[hazardId];
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  _UpcomingHazardWarning? _computeUpcomingHazardWarning({
    required LatLng currentLocation,
    required List<Hazard> hazards,
  }) {
    if (!_isNavigating) return null;
    final route = _navigationRoute;
    if (route == null || route.length < 2) return null;

    _ensureNavigationRouteCache();
    final cumulativeMeters = _navigationRouteCumulativeMeters;
    if (cumulativeMeters == null || cumulativeMeters.length != route.length) {
      return null;
    }

    final currentProjection = _projectPointOntoRouteMeters(
      point: currentLocation,
      route: route,
      cumulativeMeters: cumulativeMeters,
    );
    if (currentProjection == null) return null;
    final currentAlong = currentProjection["along"];
    if (currentAlong == null) return null;

    // * Consider hazards that are near the route and ahead of the current position.
    const maxDistanceToRouteMeters = 180.0;
    Hazard? bestHazard;
    var bestAhead = double.infinity;

    for (final hazard in hazards) {
      if (!hazard.latitude.isFinite || !hazard.longitude.isFinite) continue;
      if (hazard.latitude == 0.0 && hazard.longitude == 0.0) continue;
      if (_isHazardMuted(hazard.id)) continue;

      final hazardLocation = LatLng(hazard.latitude, hazard.longitude);
      final hazardProjection = _projectPointOntoRouteMeters(
        point: hazardLocation,
        route: route,
        cumulativeMeters: cumulativeMeters,
      );
      if (hazardProjection == null) continue;

      final distanceToRoute = hazardProjection["distance"];
      final hazardAlong = hazardProjection["along"];
      if (distanceToRoute == null || hazardAlong == null) continue;
      if (distanceToRoute > maxDistanceToRouteMeters) continue;

      final ahead = hazardAlong - currentAlong;
      if (ahead < -30.0) continue; // * Behind the user

      final range = _hazardWarningRangeMeters(hazard);
      if (ahead > range) continue;

      if (ahead < bestAhead) {
        bestAhead = ahead;
        bestHazard = hazard;
      }
    }

    if (bestHazard == null) return null;

    // * Throttle haptics per hazard id (avoid spamming).
    final now = DateTime.now();
    final lastHaptic = _navigationHazardHapticAt[bestHazard.id];
    final shouldHaptic =
        lastHaptic == null || now.difference(lastHaptic).inSeconds >= 25;
    if (shouldHaptic) {
      _navigationHazardHapticAt[bestHazard.id] = now;
    }

    return _UpcomingHazardWarning(
      hazard: bestHazard,
      distanceAheadMeters: bestAhead,
      shouldHaptic: shouldHaptic,
    );
  }

  /// * Filter markers to prevent overlapping (minimum pixel spacing).
  /// *
  /// * Returns a filtered list where no two markers are closer than [minPixelSpacing] pixels.
  /// * Prioritizes earlier markers in the list (assumes they're already sorted by importance).
  List<T> _filterOverlappingMarkers<T>({
    required List<T> markers,
    required LatLng Function(T) getLocation,
    required double Function(T) getWidth,
    required double minPixelSpacing,
    required double zoom,
  }) {
    if (markers.isEmpty || !_isMapReady) return markers;

    // * Convert minimum pixel spacing to approximate geographic distance at this zoom.
    // * At zoom Z, 1 pixel ≈ 156543.03392 * cos(lat) / 2^Z meters.
    // * We use a rough approximation: at equator, 1 pixel ≈ 156543 / 2^Z meters.
    final metersPerPixel = 156543.03392 / math.pow(2, zoom);
    final minMeters = minPixelSpacing * metersPerPixel;

    final filtered = <T>[];
    for (final marker in markers) {
      final location = getLocation(marker);
      final width = getWidth(marker);
      final minDistance = math.max(minMeters, width * metersPerPixel * 1.2); // * At least 1.2x marker width

      // * Check if this marker is too close to any already-filtered marker.
      final tooClose = filtered.any((existing) {
        final existingLocation = getLocation(existing);
        final distance = _calculateHaversineDistance(location, existingLocation);
        return distance < minDistance;
      });

      if (!tooClose) {
        filtered.add(marker);
      }
    }

    return filtered;
  }
}

// * Toolbar button widget removed - no longer used
