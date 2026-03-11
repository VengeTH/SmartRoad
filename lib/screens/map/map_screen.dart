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
import "../../models/fuel_station.dart";
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
import "../../services/weather_service.dart";
import "../../services/location_service.dart";
import "../../services/routing_service.dart";
import "../../services/route_distance_tracker.dart";
import "../../services/location_search_service.dart";
import "../../services/known_places_service.dart";
import "../../services/poi_search_service.dart";
import "../../services/overpass_poi_service.dart";
import "../../services/speed_limit_service.dart";
import "../../services/supabase_service.dart";
import "../../services/app_preferences_service.dart";
import "../../providers/map_ui_provider.dart";
import "../../providers/sticker_provider.dart";
import "../../providers/navigation_settings_provider.dart";
import "../../models/sticker.dart";
import "../../models/recent_location.dart";
import "../../widgets/distance_indicator_widget.dart";
import "../../widgets/traffic_layer.dart";
import "../../config/traffic_config.dart";
import "../../config/regional_fuel_defaults.dart";
import "../../widgets/map_filter_panel.dart";
import "../../widgets/save_route_dialog.dart";
import "../../widgets/route_creation_dialog.dart";
import "../../providers/map_filter_provider.dart";
import "../../providers/route_creation_provider.dart";
import "../../providers/fuel_provider.dart";
import "../../models/saved_route.dart";
import "../../widgets/map_poi_marker.dart";
import "../../widgets/user_location_marker.dart";
import "../../widgets/fuel_station_detail_sheet.dart";
import "../../widgets/multi_fuel_update_dialog.dart";
import "../../widgets/add_fuel_station_dialog.dart";
import "../../widgets/navigation_hazard_warning_banner.dart";
import "../commute/commute_mode_screen.dart";
import "../fuel/fuel_prices_screen.dart";
import "../../providers/commute_provider.dart";
import "../../widgets/navigation_speed_hud.dart";
import "../../widgets/music_control_widget.dart";
import "../../utils/polyline_smoothing.dart";
import "../../models/weather_state.dart";
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
        border: Border.all(color: AppTheme.borderColor, width: 1.5),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSM,
                          ),
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
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
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
                      if (remainingDuration != null &&
                          remainingDuration!.inMinutes > 0) ...[
                        const SizedBox(width: AppTheme.spacingMD),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          "${remainingDuration!.inMinutes} min",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
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
                  color:
                      isActive
                          ? AppTheme.primaryColor.withOpacity(0.2)
                          : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 24),
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

/// * Location options bottom sheet (pin location actions)
class _LocationOptionsSheet extends StatelessWidget {
  final LatLng location;
  final String locationName;
  final String? address;
  final VoidCallback onGetDirections;
  final VoidCallback onOpenCommunityPreview;
  final VoidCallback onAddFuelStation;
  final VoidCallback onSaveLocation;
  final VoidCallback onViewOnMap;
  final VoidCallback onShare;

  const _LocationOptionsSheet({
    required this.location,
    required this.locationName,
    this.address,
    required this.onGetDirections,
    required this.onOpenCommunityPreview,
    required this.onAddFuelStation,
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLG,
              ),
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
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (address != null) ...[
                              const SizedBox(height: AppTheme.spacingXS),
                              Text(
                                address!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
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
                  const SizedBox(height: AppTheme.spacingSM),
                  // * Coordinates
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            // * Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLG,
              ),
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
                          vertical: AppTheme.spacingSM,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMD,
                          ),
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
                          vertical: AppTheme.spacingSM,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMD,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onAddFuelStation();
                      },
                      icon: const Icon(Icons.local_gas_station_outlined),
                      label: const Text("Add Fuel Station"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingSM,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMD,
                          ),
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
                              vertical: AppTheme.spacingSM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
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
                              vertical: AppTheme.spacingSM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
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
                          vertical: AppTheme.spacingSM,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
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
              border: Border.all(color: AppTheme.borderColor, width: 1.5),
            ),
            child: Icon(
              icon,
              color:
                  backgroundColor != null ? Colors.white : AppTheme.textPrimary,
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

  const _StableLocationResult({required this.location, required this.accepted});
}

/// * Map screen showing hazards on OpenStreetMap
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const double _knownPlacesMinZoom =
      9.0; // * Show curated places earlier as instant POI fallback
  static const double _dynamicPoisMinZoom =
      10.0; // * Reduce low-zoom Overpass load while keeping useful context
  static const double _navigationFollowZoom = 16.8;
  static const Duration _navigationCameraThrottle = Duration(milliseconds: 250);

  // * Marker sizing/anchoring (Google Maps-like: icon at the point, label extends right).
  static const double _poiMarkerHeight = MapPoiMarker.markerHeight;
  static const double _poiMarkerAnchorLeft = MapPoiMarker.anchorLeftPx;
  static const double _poiMarkerAnchorTop = _poiMarkerHeight / 2;

  late final MapController _mapController;
  bool _isMapReady = false;
  double _mapZoom = AppConstants.defaultZoom;
  LatLng _mapCenter = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  double _mapRotationDegrees = 0.0;
  LatLngBounds? _mapVisibleBounds;
  LatLng? _pendingMapMoveCenter;
  double? _pendingMapMoveZoom;
  double? _pendingMapMoveRotationDegrees;
  CameraFit? _pendingCameraFit;
  LatLng _currentLocation = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  // * Persistent dropped pin.
  LatLng? _pinnedLocation;
  double? _currentHeadingDegrees;
  Hazard? _selectedHazard;
  Place? _selectedPlace;
  FuelStation? _selectedFuelStation;
  List<Place> _knownPlaces = [];
  List<MapPoi> _dynamicPois = [];
  bool _isLoadingDynamicPois = false;
  bool _pendingPoiRefresh = false;
  final Map<String, List<MapPoi>> _poiResponseCache = {};
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
  final AppPreferencesService _preferencesService = AppPreferencesService();
  List<RecentLocation> _recentLocations = [];
  bool _isLoadingRecents = false;
  String? _pendingNavigationLabel;
  final RoutingService _routingService = RoutingService();
  final RouteDistanceTracker _distanceTracker = RouteDistanceTracker();
  final WeatherLayerManager _weatherLayerManager = WeatherLayerManager();
  final LocationSearchService _locationSearchService = LocationSearchService();
  final SpeedLimitService _speedLimitService = SpeedLimitService();
  final WeatherService _weatherService = WeatherService();
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

  // * Route weather alerts (ahead-of-route warnings)
  bool _isRouteWeatherCheckInProgress = false;
  DateTime? _lastRouteWeatherCheckAt;
  double? _lastRouteWeatherCheckAlongMeters;
  DateTime? _routeWeatherAlertCooldownUntil;
  DateTime? _routeWeatherAlertsMutedUntil;
  bool _isShowingRouteWeatherAlert = false;

  // * Draggable commute ball position (null = use default left: 16, bottom: 180)
  double? _commuteBallLeft;
  double? _commuteBallBottom;
  bool _showCommuteOverlay = false;
  // * Auto-dim commute ball when active (after 3s no interaction)
  bool _commuteBallDimmed = false;
  Timer? _commuteBallDimTimer;
  static const Duration _commuteBallDimDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // * Initialize map controller and location
    _mapController = MapController();
    _currentLocation = LatLng(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
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

    // * Show recents when the search field gains focus with an empty query.
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus && _searchController.text.trim().isEmpty) {
        _showRecentsOverlay();
      }
    });

    // * Preload recents so the dropdown can appear instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadRecentLocations();
      }
    });

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
    _commuteBallDimTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dio.close();
    _weatherLayerManager.dispose();
    // * RoutingService doesn't need dispose
    super.dispose();
  }

  Future<void> _loadRecentLocations() async {
    if (_isLoadingRecents) return;

    setState(() {
      _isLoadingRecents = true;
    });

    try {
      final recents = await _preferencesService.loadRecentLocations();
      if (!mounted) return;
      setState(() {
        _recentLocations = recents;
      });
    } catch (_) {
      // * Best-effort only.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecents = false;
        });
      }
    }
  }

  void _showRecentsOverlay() {
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _showSearchResults = true;
      _searchResults = [];
      _visibleSearchResults = 10;
      _searchResultDistances.clear();
      _searchResultDistanceLoading.clear();
    });
    _loadRecentLocations();
  }

  Map<String, dynamic> _recentToSearchResultMap(RecentLocation recent) {
    return {
      'display_name': recent.label,
      'lat': recent.latitude.toString(),
      'lon': recent.longitude.toString(),
      'address': null,
    };
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

  void _safeMoveAndRotateMap(
    LatLng center,
    double zoom,
    double rotationDegrees,
  ) {
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
    _zoomLimitTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
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
        if (currentZoom < AppConstants.minZoom ||
            currentZoom > AppConstants.maxZoom) {
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
      final places = await KnownPlacesService().getKnownPlaces(
        forceRefresh: kDebugMode,
      );
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
      id: _buildCommunityPlaceId(
        location: location,
        nominatimPlaceId: nominatimPlaceId,
      ),
      name: name.trim().isNotEmpty ? name.trim() : "Location",
      latitude: location.latitude,
      longitude: location.longitude,
      category: category?.trim(),
      aliases: const [],
    );
  }

  void _setPinnedLocation({required LatLng location, String? label}) {
    if (!mounted) return;
    setState(() {
      _pinnedLocation = location;
    });
  }

  FuelStation? _resolveFuelStationFromSearchResult(
    Map<String, dynamic> result,
  ) {
    final stations = ref.read(mapFuelStationsProvider).valueOrNull ?? const [];
    if (stations.isEmpty) return null;

    final lat = double.tryParse(result["lat"]?.toString() ?? "");
    final lon = double.tryParse(result["lon"]?.toString() ?? "");
    final selectedLocation =
        (lat != null && lon != null) ? LatLng(lat, lon) : null;

    final rawName = (result["display_name"] ?? "").toString();
    final primaryName = rawName.split(",").first.trim();
    final normalizedQuery = _normalizePoiName(primaryName);

    final withinRadius =
        selectedLocation == null
            ? stations
            : stations.where((s) {
              final distanceMeters = _calculateHaversineDistance(
                selectedLocation,
                s.location,
              );
              return distanceMeters <= 300;
            }).toList();

    List<FuelStation> candidatePool =
        withinRadius.isNotEmpty ? withinRadius : stations;

    if (normalizedQuery.isNotEmpty) {
      final exactNameMatches =
          candidatePool
              .where((s) => _normalizePoiName(s.name) == normalizedQuery)
              .toList();
      if (exactNameMatches.isNotEmpty) {
        candidatePool = exactNameMatches;
      } else {
        final containsNameMatches =
            candidatePool.where((s) {
              final stationName = _normalizePoiName(s.name);
              return stationName.contains(normalizedQuery) ||
                  normalizedQuery.contains(stationName);
            }).toList();
        if (containsNameMatches.isNotEmpty) {
          candidatePool = containsNameMatches;
        }
      }
    }

    candidatePool.sort((a, b) {
      if (selectedLocation == null) return 0;
      final distA = _calculateHaversineDistance(selectedLocation, a.location);
      final distB = _calculateHaversineDistance(selectedLocation, b.location);
      return distA.compareTo(distB);
    });

    return candidatePool.isEmpty ? null : candidatePool.first;
  }

  String _buildPoiRequestKey({required double zoom, required LatLng center}) {
    final zoomBucket = zoom.floor(); // * Reduce refresh spam while zooming.
    final latKey = (center.latitude * 250).round(); // ~400m bucket
    final lonKey = (center.longitude * 250).round();
    return "$zoomBucket:$latKey:$lonKey";
  }

  List<MapPoi>? _findNearbyCachedPois(String requestKey) {
    final parts = requestKey.split(":");
    if (parts.length != 3) return null;

    final zoomBucket = int.tryParse(parts[0]);
    final latKey = int.tryParse(parts[1]);
    final lonKey = int.tryParse(parts[2]);
    if (zoomBucket == null || latKey == null || lonKey == null) return null;

    List<MapPoi>? best;
    var bestDistance = 1 << 30;
    for (final entry in _poiResponseCache.entries) {
      final keyParts = entry.key.split(":");
      if (keyParts.length != 3) continue;

      final z = int.tryParse(keyParts[0]);
      final y = int.tryParse(keyParts[1]);
      final x = int.tryParse(keyParts[2]);
      if (z == null || y == null || x == null) continue;
      if (z != zoomBucket) continue;

      final distance = (y - latKey).abs() + (x - lonKey).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry.value;
      }
    }

    if (best != null && bestDistance <= 2) {
      return best;
    }

    return null;
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
    _poiDebounceTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        _loadDynamicPoisForViewport();
      }
    });
  }

  Future<void> _loadDynamicPoisForViewport() async {
    if (!_isMapReady) return;
    if (_isLoadingDynamicPois) {
      _pendingPoiRefresh = true;
      return;
    }

    final zoom = _mapZoom;
    if (_isNavigating || zoom < _dynamicPoisMinZoom) {
      return;
    }

    final now = DateTime.now();
    if (_lastPoiFetchedAt != null &&
        now.difference(_lastPoiFetchedAt!).inMilliseconds < 900) {
      return;
    }

    final center = _mapCenter;
    final requestKey = _buildPoiRequestKey(zoom: zoom, center: center);
    final cachedPois = _poiResponseCache[requestKey];
    final nearbyCachedPois = cachedPois ?? _findNearbyCachedPois(requestKey);
    if (nearbyCachedPois != null && nearbyCachedPois.isNotEmpty && mounted) {
      setState(() {
        _dynamicPois = nearbyCachedPois;
      });
    }

    if (_lastPoiRequestKey == requestKey && _lastPoiFetchedAt != null) {
      // * If previous fetch was empty, retry sooner so POIs recover quickly.
      final minRetrySeconds = _dynamicPois.isEmpty ? 0 : 2;
      if (now.difference(_lastPoiFetchedAt!).inSeconds < minRetrySeconds) {
        return;
      }
    }

    setState(() => _isLoadingDynamicPois = true);
    try {
      final bounds = _mapVisibleBounds;
      if (bounds == null) return;

      List<MapPoi> buildLimited(List<MapPoi> source, {required int maxCount}) {
        final knownNameIndex = _buildKnownPlaceNameIndex();

        // * Dedupe by Overpass element id, filtering out known places.
        final byId = <String, MapPoi>{};
        for (final poi in source) {
          final normalizedName = _normalizePoiName(poi.name);
          if (normalizedName.isEmpty) continue;
          final category = (poi.category ?? poi.type ?? "").toLowerCase();
          final isFuelPoi = category == "fuel";

          if (!isFuelPoi && knownNameIndex.contains(normalizedName)) continue;

          if (!isFuelPoi) {
            final tooCloseToKnown = _knownPlaces.any(
              (p) => _calculateHaversineDistance(p.location, poi.location) < 70,
            );
            if (tooCloseToKnown) continue;
          }

          final existing = byId[poi.id];
          if (existing == null) {
            byId[poi.id] = poi;
          } else {
            final existingImportance = existing.importance ?? 0;
            final nextImportance = poi.importance ?? 0;
            if (nextImportance > existingImportance) {
              byId[poi.id] = poi;
            }
          }
        }

        final byNameBucket = <String, MapPoi>{};
        for (final poi in byId.values) {
          final normalizedName = _normalizePoiName(poi.name);
          final latKey = (poi.latitude * 2000).round();
          final lonKey = (poi.longitude * 2000).round();
          final dedupeKey = "$normalizedName:$latKey:$lonKey";

          final existing = byNameBucket[dedupeKey];
          if (existing == null) {
            byNameBucket[dedupeKey] = poi;
          } else {
            final existingImportance = existing.importance ?? 0;
            final nextImportance = poi.importance ?? 0;
            if (nextImportance > existingImportance) {
              byNameBucket[dedupeKey] = poi;
            }
          }
        }

        final merged =
            byNameBucket.values.toList()..sort(
              (a, b) => (b.importance ?? 0).compareTo(a.importance ?? 0),
            );

        final fuels =
            merged
                .where(
                  (p) => (p.category ?? p.type ?? "").toLowerCase() == "fuel",
                )
                .toList();

        final suppressed =
            merged.where((p) {
                final cat = (p.category ?? p.type ?? "").toLowerCase();
                if (cat == "fuel") return true;
                for (final f in fuels) {
                  if (_calculateHaversineDistance(p.location, f.location) <
                      80) {
                    return false;
                  }
                }
                return true;
              }).toList()
              ..sort(
                (a, b) => (b.importance ?? 0).compareTo(a.importance ?? 0),
              );

        return suppressed.take(maxCount).toList();
      }

      // * Stage 1: fetch a smaller set first for quicker first paint.
      final quickRaw = await OverpassPoiService().fetchInBounds(
        bounds: bounds,
        zoom: zoom,
        limit: 36,
      );
      if (!mounted) return;

      final quickLimited = buildLimited(
        quickRaw,
        maxCount: zoom >= 15.0 ? 70 : (zoom >= 12.0 ? 52 : 34),
      );

      setState(() {
        // * Keep previous markers if a transient request returns empty.
        if (quickLimited.isNotEmpty || _dynamicPois.isEmpty) {
          _dynamicPois = quickLimited;
        }
        if (quickLimited.isNotEmpty) {
          _poiResponseCache[requestKey] = quickLimited;
          if (_poiResponseCache.length > 36) {
            _poiResponseCache.remove(_poiResponseCache.keys.first);
          }
        }
        _lastPoiRequestKey = requestKey;
        _lastPoiFetchedAt = now;
      });

      // * Stage 2: fetch richer set and upgrade markers if still in same viewport key.
      final fullRaw = await OverpassPoiService().fetchInBounds(
        bounds: bounds,
        zoom: zoom,
        limit: 120,
      );
      if (!mounted) return;
      final currentKey = _buildPoiRequestKey(
        zoom: _mapZoom,
        center: _mapCenter,
      );
      if (currentKey != requestKey) return;

      final fullLimited = buildLimited(
        fullRaw,
        maxCount: zoom >= 15.0 ? 120 : (zoom >= 12.0 ? 86 : 52),
      );

      if (fullLimited.length > quickLimited.length) {
        setState(() {
          _dynamicPois = fullLimited;
          _poiResponseCache[requestKey] = fullLimited;
          _lastPoiRequestKey = requestKey;
          _lastPoiFetchedAt = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Failed to load dynamic POIs: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingDynamicPois = false);
      }
      if (_pendingPoiRefresh && mounted) {
        _pendingPoiRefresh = false;
        _scheduleDynamicPoiRefresh();
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
      final movedMeters = _calculateHaversineDistance(
        _currentLocation,
        _countryCodeLocation!,
      );
      if (movedMeters < 8000) {
        return;
      }
    }

    try {
      _isDetectingCountryCode = true;
      _lastCountryCodeFetchAt = now;

      final countryCode = await _locationSearchService
          .getCountryCodeFromCoordinates(
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
      'city',
      'town',
      'village',
      'municipality',
      'administrative',
      'state',
      'province',
      'region',
      'country',
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

  String _extractPrimaryName(Map<String, dynamic> result) {
    final name = result['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final display = result['display_name']?.toString().trim() ?? '';
    if (display.isEmpty) return '';
    return display.split(',').first.trim();
  }

  double _extractImportance(Map<String, dynamic> result) {
    final raw = result['importance'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0.0;
  }

  bool _isPoiLike(Map<String, dynamic> result) {
    final classType = result['class']?.toString().toLowerCase() ?? '';
    final type = result['type']?.toString().toLowerCase() ?? '';

    // * Keep common POI classes/types (malls, terminals, hotels, restaurants, etc.)
    if (classType == 'amenity' ||
        classType == 'shop' ||
        classType == 'tourism' ||
        classType == 'leisure' ||
        classType == 'building') {
      return true;
    }

    // * Extra safety for POI-like types that come back without a clear class.
    if (type.contains('hotel') ||
        type.contains('restaurant') ||
        type.contains('mall') ||
        type.contains('terminal') ||
        type.contains('station') ||
        type.contains('hospital')) {
      return true;
    }

    return false;
  }

  LatLngBounds _boundsAround(LatLng center, {double radiusKm = 120}) {
    // * Rough conversion: 1 degree latitude ≈ 111km.
    final latDelta = radiusKm / 111.0;
    final latRad = center.latitude * (math.pi / 180.0);
    final cosLat = math.cos(latRad).abs().clamp(0.25, 1.0);
    final lonDelta = radiusKm / (111.0 * cosLat);

    return LatLngBounds(
      LatLng(center.latitude - latDelta, center.longitude - lonDelta),
      LatLng(center.latitude + latDelta, center.longitude + lonDelta),
    );
  }

  Future<List<Map<String, dynamic>>> _nominatimSearch({
    required String query,
    String? countryCode,
    LatLngBounds? viewbox,
    bool bounded = false,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'format': 'jsonv2',
        'limit': limit,
        'addressdetails': 1,
        'namedetails': 1,
        'extratags': 1,
        // * Use email instead of User-Agent on web (avoids CORS/preflight failures).
        'email': 'contact@smartroad.app',
      };

      if (countryCode != null && countryCode.trim().isNotEmpty) {
        params['countrycodes'] = countryCode.trim().toLowerCase();
      }

      if (viewbox != null) {
        // * Nominatim expects: left,top,right,bottom.
        params['viewbox'] =
            '${viewbox.west},${viewbox.north},${viewbox.east},${viewbox.south}';
        if (bounded) {
          params['bounded'] = 1;
        }
      }

      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: params,
        options: Options(
          headers:
              kIsWeb
                  ? null
                  : {'User-Agent': 'SmartRoad App (contact@smartroad.app)'},
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _openCategoryPoiSearch({
    required String title,
    required String query,
    required IconData icon,
  }) async {
    if (!mounted) return;

    final country =
        (_cachedCountryCode?.trim().isNotEmpty ?? false)
            ? _cachedCountryCode!.trim().toLowerCase()
            : 'ph';

    // * Always search around the user's current location (or map center fallback).
    // * Using visible bounds can be huge at low zoom and return far-away POIs.
    final referenceLocation =
        _hasPreciseLocation ? _currentLocation : _mapCenter;
    final bounds = _boundsAround(referenceLocation, radiusKm: 18);

    final rawPois = await PoiSearchService().searchInBounds(
      bounds: bounds,
      query: query,
      limit: 24,
      countryCode: country,
    );

    // * Sort by nearest first.
    final pois = List<MapPoi>.from(rawPois)..sort((a, b) {
      final distA = _calculateStraightLineDistance(
        referenceLocation,
        a.location,
      );
      final distB = _calculateStraightLineDistance(
        referenceLocation,
        b.location,
      );
      return distA.compareTo(distB);
    });

    if (!mounted) return;

    if (pois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No nearby $title found'),
          backgroundColor: AppTheme.infoColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
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
                  padding: const EdgeInsets.all(AppTheme.spacingLG),
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.primaryColor),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pois.length,
                    separatorBuilder:
                        (context, index) =>
                            Divider(height: 1, color: AppTheme.borderColor),
                    itemBuilder: (context, index) {
                      final poi = pois[index];
                      final distanceKm = _calculateStraightLineDistance(
                        referenceLocation,
                        poi.location,
                      );
                      final rawPlaceId =
                          poi.id.startsWith('nominatim:')
                              ? poi.id.substring('nominatim:'.length)
                              : poi.id;

                      return ListTile(
                        leading: Icon(icon, color: AppTheme.primaryColor),
                        title: Text(
                          poi.name,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatDistance(distanceKm)} away',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        trailing: Text(
                          _formatDistance(distanceKm),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          final normalizedCategory =
                              (poi.type ?? poi.category ?? "")
                                  .trim()
                                  .toLowerCase();
                          _selectSearchResult({
                            'display_name': poi.name,
                            'lat': poi.latitude.toString(),
                            'lon': poi.longitude.toString(),
                            'place_id': rawPlaceId,
                            'type': poi.type,
                            'sr_kind': 'overpass_poi',
                            'sr_poi_id': poi.id,
                            'sr_poi_category': normalizedCategory,
                            'address': null,
                          });
                        },
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// * Search for locations using Nominatim API
  /// * Prioritizes current country results, then shows global main cities
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      // * Empty query: show recent searches/navigation if available.
      _showRecentsOverlay();
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
      final trimmed = query.trim();
      final normalizedQuery = trimmed.toLowerCase();
      final country =
          (_cachedCountryCode?.trim().isNotEmpty ?? false)
              ? _cachedCountryCode!.trim().toLowerCase()
              : null;

      final combined = <Map<String, dynamic>>[];

      // * Local-first search: include visible fuel stations + dynamic POIs + known places.
      // * This ensures queries like "ntn" and "sjr" match what the user already sees on the map.
      combined.addAll(_buildLocalSearchResults(trimmed));

      // * Pass 0: Nearby bounded search (keeps local POIs like "Starmall Alabang" on top).
      if (_hasPreciseLocation) {
        final nearbyBounds = _boundsAround(_currentLocation, radiusKm: 160);
        final nearby = await _nominatimSearch(
          query: trimmed,
          countryCode: country,
          viewbox: nearbyBounds,
          bounded: true,
          limit: 18,
        );
        combined.addAll(nearby);
      }

      // * Pass 1: Country-wide search (keeps POIs; avoids global noise).
      if (country != null && country.isNotEmpty) {
        final countryResults = await _nominatimSearch(
          query: trimmed,
          countryCode: country,
          limit: 26,
        );
        combined.addAll(countryResults);
      } else {
        // * No country detected yet: still do a normal global search.
        final globalResults = await _nominatimSearch(query: trimmed, limit: 18);
        combined.addAll(globalResults);
      }

      // * Optional global fallback: only if we have too few results.
      // ! Avoid global fallback when we already have local matches or a country code.
      final hasLocalMatches = combined.any((r) => r.containsKey("sr_score"));
      final shouldFetchGlobal =
          !hasLocalMatches &&
          (country == null || country.isEmpty) &&
          combined.length < 10;
      if (shouldFetchGlobal) {
        final globalResults = await _nominatimSearch(query: trimmed, limit: 24);
        combined.addAll(globalResults);
      }

      // * De-dupe by coordinates.
      final unique = <String, Map<String, dynamic>>{};
      for (final result in combined) {
        final lat = result['lat']?.toString();
        final lon = result['lon']?.toString();
        if (lat == null || lon == null) continue;
        unique['${lat}_$lon'] ??= result;
      }

      final results =
          unique.values.where((result) {
            // * On global fallback, keep only likely-relevant results.
            if (!shouldFetchGlobal) return true;

            final name = _extractPrimaryName(result).toLowerCase();
            final display =
                result['display_name']?.toString().toLowerCase() ?? '';
            final hasTextMatch =
                name.contains(normalizedQuery) ||
                display.contains(normalizedQuery);
            if (!hasTextMatch) return false;

            final importance = _extractImportance(result);
            final isCity = _isMainCity(result);
            final isPoi = _isPoiLike(result);

            // * Avoid random far-away streets unless they are significant.
            return isPoi || isCity || importance >= 0.55;
          }).toList();

      // * Sort: country first → name match → near→far → popularity.
      results.sort((a, b) {
        final aName = _extractPrimaryName(a);
        final bName = _extractPrimaryName(b);
        final aNameLower = aName.toLowerCase();
        final bNameLower = bName.toLowerCase();

        bool inCountry(Map<String, dynamic> r) {
          final addr = r['address'];
          if (addr is Map) {
            final cc = addr['country_code']?.toString().toLowerCase();
            if (cc != null && cc.isNotEmpty) {
              return country != null && cc == country;
            }
          }
          // * If there is no explicit country_code, do not assume it matches.
          return false;
        }

        // * Local results always win (fuel stations + visible POIs).
        final aLocal = a.containsKey("sr_score") ? 1 : 0;
        final bLocal = b.containsKey("sr_score") ? 1 : 0;
        if (aLocal != bLocal) return bLocal - aLocal;

        final aInCountry = inCountry(a) ? 1 : 0;
        final bInCountry = inCountry(b) ? 1 : 0;
        if (aInCountry != bInCountry) return bInCountry - aInCountry;

        final aStarts = aNameLower.startsWith(normalizedQuery) ? 1 : 0;
        final bStarts = bNameLower.startsWith(normalizedQuery) ? 1 : 0;
        if (aStarts != bStarts) return bStarts - aStarts;

        final aContains = aNameLower.contains(normalizedQuery) ? 1 : 0;
        final bContains = bNameLower.contains(normalizedQuery) ? 1 : 0;
        if (aContains != bContains) return bContains - aContains;

        final aLat = double.tryParse(a['lat']?.toString() ?? '');
        final aLon = double.tryParse(a['lon']?.toString() ?? '');
        final bLat = double.tryParse(b['lat']?.toString() ?? '');
        final bLon = double.tryParse(b['lon']?.toString() ?? '');
        final aDist =
            (aLat != null && aLon != null)
                ? _calculateStraightLineDistance(
                  _currentLocation,
                  LatLng(aLat, aLon),
                )
                : 1e9;
        final bDist =
            (bLat != null && bLon != null)
                ? _calculateStraightLineDistance(
                  _currentLocation,
                  LatLng(bLat, bLon),
                )
                : 1e9;
        final distCmp = aDist.compareTo(bDist);
        if (distCmp != 0) return distCmp;

        final aImp = _extractImportance(a);
        final bImp = _extractImportance(b);
        return bImp.compareTo(aImp);
      });

      // * Cap results to keep the UI clean (Google-like; still expandable with "Show More").
      final finalResults = results.take(30).toList();

      setState(() {
        _searchResults = finalResults;
        _isSearching = false;
        _visibleSearchResults = 10;
      });

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

  /// * Build local-first search results from map-visible datasets.
  /// *
  /// * This makes POIs and gas stations searchable even if Nominatim returns nothing
  /// * (or returns out-of-country matches).
  List<Map<String, dynamic>> _buildLocalSearchResults(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final q = trimmed.toLowerCase();
    final results = <Map<String, dynamic>>[];

    int scoreText(String name) {
      final n = name.toLowerCase();
      if (n == q) return 100;
      if (n.startsWith(q)) return 80;
      if (n.contains(q)) return 60;
      return 0;
    }

    int queryBoost(String name) {
      final n = name.toLowerCase();
      if (q == "ntn") {
        if (n.contains("ntn")) return 40;
        if (n.contains("south emerald")) return -12;
      }
      return 0;
    }

    // * Fuel stations already loaded from Supabase (within bounds/viewport).
    final fuelStations =
        ref.read(mapFuelStationsProvider).valueOrNull ?? const [];
    for (final s in fuelStations) {
      final score = scoreText(s.name);
      if (score <= 0) continue;
      results.add({
        "display_name": s.name,
        "lat": s.latitude,
        "lon": s.longitude,
        "address": null,
        "type": "fuel",
        "sr_kind": "fuel_station",
        "sr_station_id": s.id,
        "sr_score":
            score + 30 + queryBoost(s.name), // * Prefer explicit fuel stations
      });
    }

    // * Dynamic POIs from Overpass currently visible on the map.
    for (final poi in _dynamicPois) {
      final score = scoreText(poi.name);
      if (score <= 0) continue;
      final category = (poi.type ?? poi.category ?? "").trim();
      final isFuel = category == "fuel";
      results.add({
        "display_name": poi.name,
        "lat": poi.latitude,
        "lon": poi.longitude,
        "address": null,
        "type": category,
        "sr_kind": "overpass_poi",
        "sr_poi_id": poi.id,
        "sr_poi_category": category,
        "sr_score": score + (isFuel ? 20 : 0) + queryBoost(poi.name),
      });
    }

    // * Known places shipped with the app.
    for (final p in _knownPlaces) {
      final aliasScore = p.aliases.fold<int>(
        0,
        (best, alias) => math.max(best, scoreText(alias)),
      );
      final score = math.max(scoreText(p.name), aliasScore);
      if (score <= 0) continue;
      results.add({
        "display_name": p.name,
        "lat": p.latitude,
        "lon": p.longitude,
        "address": null,
        "type": p.category,
        "sr_kind": "known_place",
        "sr_place_id": p.id,
        "sr_score": score + queryBoost(p.name),
      });
    }

    // * Sort local results by score then distance
    results.sort((a, b) {
      final aScore =
          (a["sr_score"] is num) ? (a["sr_score"] as num).toInt() : 0;
      final bScore =
          (b["sr_score"] is num) ? (b["sr_score"] as num).toInt() : 0;
      if (aScore != bScore) return bScore.compareTo(aScore);

      final aLat = double.tryParse(a["lat"]?.toString() ?? "");
      final aLon = double.tryParse(a["lon"]?.toString() ?? "");
      final bLat = double.tryParse(b["lat"]?.toString() ?? "");
      final bLon = double.tryParse(b["lon"]?.toString() ?? "");
      final aDist =
          (aLat != null && aLon != null)
              ? _calculateStraightLineDistance(
                _currentLocation,
                LatLng(aLat, aLon),
              )
              : 1e9;
      final bDist =
          (bLat != null && bLon != null)
              ? _calculateStraightLineDistance(
                _currentLocation,
                LatLng(bLat, bLon),
              )
              : 1e9;
      return aDist.compareTo(bDist);
    });

    return results.take(12).toList();
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
  Future<void> _calculateSearchResultDistances(
    List<Map<String, dynamic>> results,
  ) async {
    // * Always calculate distances - use current location (even if it's default)
    // * This allows distance to show for all search results

    debugPrint(
      "📍 [MapScreen] Calculating distances for ${results.length} search results from location: (${_currentLocation.latitude}, ${_currentLocation.longitude})",
    );

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
        final fallbackDistance = _calculateStraightLineDistance(
          _currentLocation,
          destination,
        );

        // * Mark as loading and show fallback distance immediately
        setState(() {
          _searchResultDistanceLoading[resultKey] = true;
          _searchResultDistances[resultKey] =
              fallbackDistance; // * Show fallback while calculating route
        });

        // * Calculate route distance in background
        try {
          debugPrint(
            "📍 [MapScreen] Calculating route distance from (${_currentLocation.latitude}, ${_currentLocation.longitude}) to ($lat, $lon)",
          );
          final route = await _routingService.calculateRoute(
            start: _currentLocation,
            end: destination,
            vehicle: VehicleType.car, // * Use car as default for search results
            avoidTolls: _avoidTollsToggle,
          );

          debugPrint(
            "✅ [MapScreen] Route distance calculated: ${route.distance.toStringAsFixed(2)} km",
          );
          // * Store actual route distance in km (replaces fallback)
          if (mounted) {
            setState(() {
              _searchResultDistances[resultKey] = route.distance;
              _searchResultDistanceLoading[resultKey] = false;
            });
          }
        } catch (e) {
          // * If route calculation fails, keep the fallback distance
          debugPrint(
            "⚠️ [MapScreen] Route calculation failed for search result: $e",
          );
          debugPrint(
            "⚠️ [MapScreen] Using fallback straight-line distance: ${fallbackDistance.toStringAsFixed(2)} km",
          );
          if (mounted) {
            setState(() {
              // * Keep fallback distance, just stop loading
              _searchResultDistanceLoading[resultKey] = false;
            });
          }
        }
      } catch (e) {
        debugPrint(
          "❌ [MapScreen] Error calculating distance for search result: $e",
        );
        final resultKey = "${result['lat']}_${result['lon']}";
        // * On error, calculate fallback straight-line distance
        try {
          final lat = double.tryParse(result['lat']?.toString() ?? '');
          final lon = double.tryParse(result['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final destination = LatLng(lat, lon);
            final fallbackDistance = _calculateStraightLineDistance(
              _currentLocation,
              destination,
            );
            debugPrint(
              "📍 [MapScreen] Using fallback distance: ${fallbackDistance.toStringAsFixed(2)} km",
            );
            if (mounted) {
              setState(() {
                _searchResultDistances[resultKey] = fallbackDistance;
                _searchResultDistanceLoading[resultKey] = false;
              });
            }
          }
        } catch (fallbackError) {
          debugPrint(
            "❌ [MapScreen] Fallback distance calculation also failed: $fallbackError",
          );
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
        math.cos(start.latitude * (math.pi / 180.0)) *
            math.cos(end.latitude * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

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

  String _formatRecentAge(DateTime updatedAt) {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  String _recentSummaryLabel() {
    if (_recentLocations.isEmpty) return "No recents";
    final latest = _recentLocations
        .map((e) => e.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return "${_recentLocations.length} • ${_formatRecentAge(latest)}";
  }

  RecentLocation? _findRecentMatchForPlace(Place place) {
    if (_recentLocations.isEmpty) return null;

    final normalizedName = place.name.trim().toLowerCase();
    RecentLocation? best;
    double bestDistanceKm = double.infinity;

    for (final recent in _recentLocations) {
      final distanceKm = _calculateDistance(
        place.location,
        LatLng(recent.latitude, recent.longitude),
      );

      if (distanceKm > 0.3) {
        continue;
      }

      final recentLabel = recent.label.trim().toLowerCase();
      final nameMatches =
          recentLabel.isNotEmpty &&
          (normalizedName.contains(recentLabel) ||
              recentLabel.contains(normalizedName));

      if (!nameMatches && distanceKm > 0.12) {
        continue;
      }

      if (distanceKm < bestDistanceKm) {
        bestDistanceKm = distanceKm;
        best = recent;
      }
    }

    return best;
  }

  double _getSearchResultsDropdownMaxHeight(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = math.max(0.0, viewportHeight - keyboardInset);

    final hasResults = _searchResults.isNotEmpty;
    final isExpanded =
        hasResults && _visibleSearchResults >= _searchResults.length;

    // * When expanded (after tapping "Show More"), allow the dropdown to take up
    // * more of the viewport so results feel immediately visible.
    final fraction = isExpanded ? 0.75 : 0.5;
    final computed = availableHeight * fraction;

    // * Keep within sensible bounds for small/large screens.
    return computed.clamp(240.0, availableHeight * 0.9);
  }

  /// * Handle end point selection - close dialog and calculate route safely
  Future<void> _handleEndPointSelected() async {
    if (!mounted || _customStartPoint == null || _customEndPoint == null)
      return;

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
        final wasSelectingStart =
            _selectingStartPoint; // * Remember before state change
        final bool justSetEndPoint =
            !_selectingStartPoint && _customEndPoint == null;

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
        if (justSetEndPoint &&
            _customStartPoint != null &&
            _customEndPoint != null) {
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
      final selectedFuelStation = _resolveFuelStationFromSearchResult(result);

      // * Local-first result: fuel station selection should open station UI directly.
      final srKind = result["sr_kind"]?.toString();
      if (srKind == "fuel_station") {
        final stationId = result["sr_station_id"]?.toString();
        final stations =
            ref.read(mapFuelStationsProvider).valueOrNull ?? const [];
        FuelStation? station;
        if (stationId != null && stationId.trim().isNotEmpty) {
          final match = stations.where((s) => s.id == stationId).toList();
          if (match.isNotEmpty) {
            station = match.first;
          }
        }
        station ??= selectedFuelStation;
        if (station != null) {
          setState(() {
            _selectedFuelStation = station;
            _selectedHazard = null;
            _selectedPlace = null;
            _pinnedLocation = null;
            _showSearchResults = false;
            _searchFocusNode.unfocus();
          });
          _safeMoveMap(station.location, 16.0);
          return;
        }
      }

      // * Local-first result: Overpass fuel POI should open fuel station UI.
      if (srKind == "overpass_poi") {
        final category = result["sr_poi_category"]?.toString().trim();
        if (category == "fuel") {
          if (selectedFuelStation != null) {
            setState(() {
              _selectedFuelStation = selectedFuelStation;
              _selectedHazard = null;
              _selectedPlace = null;
              _pinnedLocation = null;
              _showSearchResults = false;
              _searchFocusNode.unfocus();
            });
            _safeMoveMap(selectedFuelStation.location, 16.0);
            return;
          }

          final name =
              (result["display_name"] ?? "Fuel Station").toString().trim();
          final lat = double.tryParse(result["lat"]?.toString() ?? "");
          final lon = double.tryParse(result["lon"]?.toString() ?? "");
          if (lat != null && lon != null) {
            final station = FuelStation(
              id: (result["sr_poi_id"] ?? "overpass_fuel").toString(),
              name: name.isNotEmpty ? name : "Fuel Station",
              latitude: lat,
              longitude: lon,
              brand: null,
              province: "",
              city: "",
              region: null,
              verified: false,
              source: "osm",
              prices: RegionalFuelDefaults.getDefaultPricesForStation("", null),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            setState(() {
              _selectedFuelStation = station;
              _selectedHazard = null;
              _selectedPlace = null;
              _pinnedLocation = null;
              _showSearchResults = false;
              _searchFocusNode.unfocus();
            });
            _safeMoveMap(station.location, 16.0);
            return;
          }
        }
      }

      final isFuelTypeResult =
          (result['type']?.toString().trim().toLowerCase() ?? '') == 'fuel';
      if (isFuelTypeResult) {
        if (selectedFuelStation != null) {
          setState(() {
            _selectedFuelStation = selectedFuelStation;
            _selectedHazard = null;
            _selectedPlace = null;
            _pinnedLocation = null;
            _showSearchResults = false;
            _searchFocusNode.unfocus();
          });
          _safeMoveMap(selectedFuelStation.location, 16.0);
          return;
        }
      }

      final lat = double.parse(result['lat'].toString());
      final lon = double.parse(result['lon'].toString());
      final location = LatLng(lat, lon);

      // * Drop a persistent pin so the location stays visible on the map.
      final fullName = (result["display_name"] ?? "Location").toString().trim();
      final shortName = fullName.split(",").first.trim();
      final pinLabel =
          shortName.isNotEmpty
              ? shortName
              : (fullName.isNotEmpty ? fullName : null);
      _setPinnedLocation(location: location, label: pinLabel);

      // * Persist as a recent search (best-effort).
      final label =
          shortName.isNotEmpty
              ? shortName
              : (fullName.isNotEmpty ? fullName : "Location");
      try {
        final recents = await _preferencesService.addRecentLocation(
          label: label,
          latitude: location.latitude,
          longitude: location.longitude,
          kind: RecentLocationKind.search,
        );
        if (mounted) {
          setState(() {
            _recentLocations = recents;
          });
        }
      } catch (_) {
        // * Best-effort only.
      }

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

  /// * Show location options bottom sheet
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
      builder:
          (context) => _LocationOptionsSheet(
            location: location,
            locationName:
                shortName.isNotEmpty
                    ? shortName
                    : (fullName.isNotEmpty ? fullName : "Location"),
            address:
                result["address"] != null
                    ? _formatAddress(result["address"] as Map<String, dynamic>)
                    : null,
            onGetDirections: () {
              Navigator.of(context).pop();
              // * Keep a label for recent navigation.
              _pendingNavigationLabel =
                  fullName.isNotEmpty ? fullName : shortName;
              _openDirections(location);
            },
            onOpenCommunityPreview: () {
              Navigator.of(context).pop();
              if (!mounted) return;
              setState(() {
                _selectedPlace = communityPlace;
                _selectedHazard = null;
                _selectedFuelStation = null;
                _showSearchResults = false;
              });
              _searchFocusNode.unfocus();
            },
            onAddFuelStation: () {
              Navigator.of(context).pop();
              if (!mounted) return;
              _showAddFuelStationDialog(location);
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
  String?
  _navigationMode; // 'car', 'motorcycle_sub400', 'motorcycle_400plus', 'truck', 'public_transit', 'tricycle'
  List<LatLng>? _navigationRoute;

  // * Navigation camera (driver-focused follow mode)
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
  bool _showSheetReopenButton =
      false; // * Show button to reopen minimized sheet

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

  // * Reroute confirmation controls (safety-first: avoid surprising reroutes).
  bool _isShowingReroutePrompt = false;
  DateTime? _reroutePromptsMutedUntil;
  DateTime? _lastRerouteConfirmationAt;
  DateTime? _lastPostRerouteWeatherAdvisoryAt;

  // * Route progress state
  double _remainingDistance = 0.0;
  Duration _remainingDuration = Duration.zero;

  // * Distance indicators state
  DistanceIndicators? _distanceIndicators;

  // * Navigation hazard warnings (on-route alerts)
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

  bool get _canCreateOrSaveRoutes => SupabaseService().isAuthenticated;

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
              orElse:
                  () =>
                      hoas.isNotEmpty
                          ? hoas.first
                          : HOA(
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
            builder:
                (context) => RoutePreviewSheet(
                  route: route,
                  vehicleType: vehicleType,
                  vehicleModeName: vehicleModeName,
                  onSaveRoute:
                      _canCreateOrSaveRoutes
                          ? () {
                            Navigator.of(
                              context,
                            ).pop(); // * Close preview sheet
                            if (mounted) {
                              setState(() {
                                _navigationMode = mode;
                                _navigationDestination = destination;
                                _customStartPoint = _currentLocation;
                                _customEndPoint = destination;
                              });
                              _showSaveRouteDialog();
                            }
                          }
                          : null,
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
                  onApplyForSticker:
                      route.metadata?.blockedShortcut ?? false
                          ? () {
                            Navigator.of(
                              context,
                            ).pop(); // * Close preview sheet
                            // * Navigate to stickers screen
                            // * FUTURE (Post-MVP): Navigate to sticker purchase/application screen
                            // * FUTURE (Post-MVP): Payment integration (GCash, PayMaya, Stripe)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Navigate to sticker application for $hoaName",
                                ),
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

    // * Persist as a recent navigation destination (best-effort).
    try {
      final label =
          (_pendingNavigationLabel?.trim().isNotEmpty ?? false)
              ? _pendingNavigationLabel!.trim()
              : "Navigation destination";
      final recents = await _preferencesService.addRecentLocation(
        label: label,
        latitude: destination.latitude,
        longitude: destination.longitude,
        kind: RecentLocationKind.navigation,
      );
      if (mounted) {
        setState(() {
          _recentLocations = recents;
          _pendingNavigationLabel = null;
        });
      }
    } catch (_) {
      _pendingNavigationLabel = null;
    }
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

    // * Navigation camera: zoom-in + follow current position (driver-focused).
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
              Icon(_getNavigationModeIcon(mode), color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Navigation started (${_getNavigationModeName(mode)} mode)",
                ),
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
  Future<void> _calculateRoute(
    LatLng destination,
    String mode, {
    LatLng? origin,
    List<LatLng>? waypoints,
  }) async {
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

      debugPrint(
        "📍 [MapScreen] Calculating route: mode=$backendMode, avoidTolls=$avoidTolls",
      );

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
      final restrictedHoaIds =
          hoas
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
        waypoints:
            waypoints ??
            _routeControlPoints, // * Use control points if provided
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

      debugPrint(
        "📍 [MapScreen] Route calculated: "
        "${_routeDistance.toStringAsFixed(2)} km, "
        "${(_routeDuration.inMinutes).toStringAsFixed(1)} min",
      );

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
                  Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
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
        final isConnectionError =
            errorMessage.contains("Cannot connect") ||
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
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
    if (_navigationRoute == null ||
        _navigationRoute!.isEmpty ||
        !_isNavigating) {
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
        _remainingDistance = _calculateRemainingDistance(
          _upcomingRoute,
          _currentLocation,
        );

        // * Estimate remaining time based on average speed
        if (_routeDistance > 0 && _routeDuration.inSeconds > 0) {
          final avgSpeedKmh = (_routeDistance / _routeDuration.inHours);
          if (avgSpeedKmh > 0) {
            final remainingHours = (_remainingDistance / 1000) / avgSpeedKmh;
            _remainingDuration = Duration(
              seconds: (remainingHours * 3600).round(),
            );
          }
        }
      }
    });
  }

  /// * Check if user is off-route
  /// * Returns true if distance to route > 100m
  bool _checkOffRoute(LatLng currentPosition) {
    if (_navigationRoute == null ||
        _navigationRoute!.isEmpty ||
        !_isNavigating) {
      return false;
    }

    final distanceToRoute = _calculateDistanceToRoute(
      currentPosition,
      _navigationRoute!,
    );

    setState(() {
      _isOffRoute = distanceToRoute > 100.0; // * 100m threshold
    });

    return _isOffRoute;
  }

  /// * Recalculate route from current position
  Future<void> _recalculateRouteFromCurrentPosition() async {
    if (_isRerouting ||
        _navigationDestination == null ||
        _navigationMode == null) {
      return;
    }

    // * Debounce: Don't reroute if last reroute was less than 3 seconds ago
    if (_lastRerouteTime != null) {
      final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
      if (timeSinceLastReroute.inSeconds < 3) {
        debugPrint(
          "📍 [MapScreen] Reroute debounced (${timeSinceLastReroute.inSeconds}s ago)",
        );
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
              const Expanded(child: Text("Recalculating route...")),
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
        final splitResult = _splitRouteAtPoint(
          _navigationRoute!,
          _currentLocation,
        );
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

      // * After reroute, check if the weather ahead is still risky.
      _maybeShowPostRerouteWeatherAdvisory();
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

  bool _areReroutePromptsMuted() {
    final until = _reroutePromptsMutedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Future<bool> _confirmRerouteIfNeeded({
    required String title,
    required String message,
    bool forcePrompt = false,
  }) async {
    if (!mounted || !context.mounted) return false;
    if (_isShowingReroutePrompt) return false;

    // * If the user explicitly tapped "Recalculate" (weather sheet), we treat that as confirmation.
    if (!forcePrompt) {
      // * Avoid spamming: allow a short quiet period after a confirmation.
      final lastConfirmed = _lastRerouteConfirmationAt;
      if (lastConfirmed != null &&
          DateTime.now().difference(lastConfirmed).inSeconds < 15) {
        return true;
      }

      if (_areReroutePromptsMuted()) {
        return false;
      }
    }

    _isShowingReroutePrompt = true;
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
              boxShadow: AppTheme.shadowLarge,
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD,
                            ),
                            border: Border.all(
                              color: AppTheme.infoColor.withOpacity(0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.alt_route_rounded,
                            color: AppTheme.infoColor,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              Text(
                                message,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(false);
                              // * Mute prompts briefly so the user can keep driving without spam.
                              _reroutePromptsMutedUntil = DateTime.now().add(
                                const Duration(minutes: 3),
                              );
                            },
                            child: const Text("Not now"),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(true);
                            },
                            icon: const Icon(Icons.alt_route_rounded),
                            label: const Text("Reroute"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingMD,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(false);
                      },
                      child: const Text("Continue on current route"),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final confirmed = result == true;
      if (confirmed) {
        _lastRerouteConfirmationAt = DateTime.now();
      }
      return confirmed;
    } finally {
      _isShowingReroutePrompt = false;
    }
  }

  Future<void> _maybeTriggerRerouteWithConfirmation({
    required String title,
    required String message,
  }) async {
    if (_isRerouting) return;
    if (_navigationDestination == null || _navigationMode == null) return;

    final shouldReroute = await _confirmRerouteIfNeeded(
      title: title,
      message: message,
    );
    if (!shouldReroute) return;

    await _recalculateRouteFromCurrentPosition();
  }

  Future<void> _maybeShowPostRerouteWeatherAdvisory() async {
    if (!_isNavigating) return;
    if (_navigationRoute == null || _navigationRoute!.length < 2) return;
    if (!_hasPreciseLocation) return;
    if (_isRouteWeatherAlertsMuted()) return;

    final now = DateTime.now();
    final last = _lastPostRerouteWeatherAdvisoryAt;
    if (last != null && now.difference(last).inMinutes < 5) {
      return;
    }

    // * Quick summary: sample weather a few km ahead; if still risky, inform user.
    _ensureNavigationRouteCache();
    final route = _navigationRoute;
    final cumulativeMeters = _navigationRouteCumulativeMeters;
    if (route == null || cumulativeMeters == null) return;
    if (cumulativeMeters.length != route.length) return;

    final projection = _projectPointOntoRouteMeters(
      point: _currentLocation,
      route: route,
      cumulativeMeters: cumulativeMeters,
    );
    final currentAlong = projection?["along"];
    if (currentAlong == null) return;

    WeatherData? worst;
    double? worstOffsetMeters;
    for (final offset in const [2000.0, 6000.0, 12000.0]) {
      final samplePoint = _pointAlongRouteMeters(
        route: route,
        cumulativeMeters: cumulativeMeters,
        targetAlongMeters: currentAlong + offset,
      );
      if (samplePoint == null) continue;

      final data = await _weatherService.fetchWeatherData(center: samplePoint);
      if (data == null) continue;
      if (_isDangerousRouteWeather(data)) {
        worst = worst == null ? data : _pickMoreSevereWeather(worst, data);
        worstOffsetMeters ??= offset;
      }
    }

    if (worst == null || worstOffsetMeters == null) {
      return;
    }

    _lastPostRerouteWeatherAdvisoryAt = now;
    if (!mounted) return;

    final kmAhead = worstOffsetMeters / 1000.0;
    final distanceText =
        kmAhead < 1.0
            ? "~${worstOffsetMeters.round()} m"
            : "~${kmAhead.toStringAsFixed(1)} km";

    final weatherLabel = _routeWeatherTitle(worst);
    final suggestion =
        "$weatherLabel still detected $distanceText ahead. Consider leaving later, or proceed cautiously.";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(suggestion),
        backgroundColor: AppTheme.warningColor,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "Proceed",
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
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
      builder:
          (context) => Container(
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(
                          "${_availableRoutes.length} routes available",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: AppTheme.spacingLG),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _availableRoutes.length,
                            separatorBuilder:
                                (context, index) =>
                                    const SizedBox(height: AppTheme.spacingMD),
                            itemBuilder: (context, index) {
                              final route = _availableRoutes[index];
                              final isSelected = index == _selectedRouteIndex;
                              final distanceKm =
                                  route.distance; // * Already in km
                              final durationMin = route.duration.inMinutes;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    _selectRoute(index);
                                    Navigator.of(context).pop();
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMD,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingMD,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? AppTheme.primaryColor
                                                : AppTheme.borderColor,
                                        width: isSelected ? 2.0 : 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMD,
                                      ),
                                      color:
                                          isSelected
                                              ? AppTheme.primaryColor
                                                  .withOpacity(0.1)
                                              : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? AppTheme.primaryColor
                                                    : AppTheme.primaryColor
                                                        .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusMD,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "${index + 1}",
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                color:
                                                    isSelected
                                                        ? Colors.white
                                                        : AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingMD,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Route ${index + 1}",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(
                                                height: AppTheme.spacingXS,
                                              ),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.straighten,
                                                    size: 16,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingXS,
                                                  ),
                                                  Text(
                                                    "${distanceKm.toStringAsFixed(1)} km",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              AppTheme
                                                                  .textSecondary,
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingMD,
                                                  ),
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingXS,
                                                  ),
                                                  Text(
                                                    "$durationMin min",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              AppTheme
                                                                  .textSecondary,
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
      builder:
          (context) => RouteCreationDialog(
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
      _showSheetReopenButton =
          false; // * Hide reopen button when sheet is shown
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
          _showSheetReopenButton =
              size <= 0.15; // * Slightly above 0.1 to account for snap
        });
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3), // * Semi-transparent barrier
      isDismissible:
          false, // * Prevent accidental dismissal - user must use buttons
      enableDrag: true, // * Allow dragging to minimize
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: DraggableScrollableSheet(
                    controller: draggableController,
                    initialChildSize:
                        0.4, // * Larger initial size for better visibility
                    minChildSize:
                        0.1, // * Can be minimized to just a small bar (10%) to see map
                    maxChildSize: 0.7,
                    expand: false,
                    snap: true, // * Snap to min/max sizes for better UX
                    snapSizes: const [
                      0.1,
                      0.4,
                      0.7,
                    ], // * Snap points: minimized, default, expanded
                    builder:
                        (context, scrollController) => SingleChildScrollView(
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
                                      color: AppTheme.textSecondary.withOpacity(
                                        0.3,
                                      ),
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
                                      icon: const Icon(
                                        Icons.visibility_off,
                                        size: 20,
                                      ),
                                      tooltip: "Hide sheet (tap map to select)",
                                      onPressed: () {
                                        // * Hide sheet but maintain state so map taps work
                                        Navigator.pop(context);
                                        // * State is maintained - _isSelectingCustomPoints stays true
                                        // * Show floating button to reopen sheet
                                        setState(() {
                                          _showSheetReopenButton = true;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              _selectingStartPoint
                                                  ? "Sheet hidden. Tap on map to select START point."
                                                  : "Sheet hidden. Tap on map to select END point.",
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: AppTheme.primaryColor,
                                            ),
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
                                            Icon(
                                              Icons.arrow_downward,
                                              size: 16,
                                              color: AppTheme.textSecondary,
                                            ),
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
                                    color: AppTheme.successColor.withOpacity(
                                      0.1,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.location_on,
                                        color: Colors.green,
                                        size: 32,
                                      ),
                                      title: const Text(
                                        "Start Point",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${_customStartPoint!.latitude.toStringAsFixed(6)}, ${_customStartPoint!.longitude.toStringAsFixed(6)}",
                                      ),
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
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.flag,
                                        color: Colors.red,
                                        size: 32,
                                      ),
                                      title: const Text(
                                        "End Point",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${_customEndPoint!.latitude.toStringAsFixed(6)}, ${_customEndPoint!.longitude.toStringAsFixed(6)}",
                                      ),
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
                                        _selectingStartPoint =
                                            false; // * Switch to selecting end point
                                      });
                                      setState(() {
                                        _customStartPoint = _currentLocation;
                                        _selectingStartPoint =
                                            false; // * Switch to selecting end point
                                        // * Ensure _isSelectingCustomPoints stays true so map taps work even when minimized
                                        _isSelectingCustomPoints = true;
                                      });
                                      // * Show feedback
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Start point set! Now tap on map to select END point.",
                                          ),
                                          duration: Duration(seconds: 2),
                                          backgroundColor:
                                              AppTheme.successColor,
                                        ),
                                      );
                                      // * Expand sheet slightly to show end point selection
                                      draggableController.animateTo(
                                        0.4,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    },
                                    icon: const Icon(Icons.my_location),
                                    label: const Text(
                                      "Use Current Location as Start",
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  ),
                                if (_selectingStartPoint)
                                  const SizedBox(height: 12),
                                // * Search for location - Only show when selecting start point
                                if (_selectingStartPoint)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // * Minimize sheet instead of closing to maintain state
                                      draggableController.animateTo(
                                        0.1, // * Minimize to small size
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                      // * Focus search bar and show search results in main screen
                                      Future.delayed(
                                        const Duration(milliseconds: 200),
                                        () {
                                          if (mounted) {
                                            _searchFocusNode.requestFocus();
                                            setState(() {
                                              _showSearchResults = true;
                                              // * Ensure state is maintained
                                              _isSelectingCustomPoints = true;
                                            });
                                          }
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.search),
                                    label: const Text(
                                      "Search for Start Location",
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                // * Show message when start point is selected
                                if (!_selectingStartPoint &&
                                    _customStartPoint != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMD,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: AppTheme.successColor,
                                          size: 20,
                                        ),
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
                                        onPressed:
                                            _customStartPoint != null &&
                                                    _customEndPoint != null
                                                ? () {
                                                  Navigator.pop(context);
                                                  setState(() {
                                                    _isSelectingCustomPoints =
                                                        false;
                                                  });
                                                  _selectVehicleAndCalculateRoute(
                                                    _customStartPoint!,
                                                    _customEndPoint!,
                                                  );
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
      builder:
          (context) => AlertDialog(
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
                    _calculateRouteWithCustomPoints(
                      start,
                      end,
                      'motorcycle_sub400',
                    );
                  },
                ),
                const SizedBox(height: 8),
                _VehicleOptionButton(
                  icon: Icons.motorcycle,
                  label: "Big Bike (400cc+)",
                  onTap: () {
                    Navigator.pop(context);
                    _calculateRouteWithCustomPoints(
                      start,
                      end,
                      'motorcycle_400plus',
                    );
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
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }

    // * Show editing instructions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Route loaded for editing. Tap on the route line to add control points. Tap a control point to move it.",
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No route to edit")));
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
        content: const Text(
          "Tap on the route line to add control points. Tap a control point to move it and adjust the route path.",
        ),
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
  Map<String, dynamic> _distanceToLineSegment(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
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

    return {'distance': distance, 'point': nearestPoint};
  }

  /// * Get minimum distance from point to route (for feedback)
  double _getMinDistanceToRoute(LatLng point) {
    if (_navigationRoute == null || _navigationRoute!.isEmpty)
      return double.infinity;

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
        math.cos(_toRadians(p1.latitude)) *
            math.cos(_toRadians(p2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
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
            content: Text(
              "Route updated (GraphHopper unavailable - route may not follow roads)",
            ),
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

        final nearest = LatLng(a.latitude + t * dy, a.longitude + t * dx);

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
    final waypoints = <LatLng>[routeStart, ...sortedControlPoints, routeEnd];

    final updatedRoute = PolylineSmoothing.catmullRomThroughWaypoints(
      waypoints,
      targetSpacingMeters: 5.0,
      minPointsPerSegment: 8,
      maxPointsPerSegment: 120,
    );

    // * Update distance + duration estimates to match the new geometry (useful for saving routes).
    double updatedDistanceKm = 0.0;
    for (int i = 0; i < updatedRoute.length - 1; i++) {
      updatedDistanceKm += _calculateDistance(
        updatedRoute[i],
        updatedRoute[i + 1],
      );
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
    final estimatedMinutes = ((updatedDistanceKm / avgSpeedKmh) * 60)
        .round()
        .clamp(1, 24 * 60 * 7);
    final updatedDuration = Duration(minutes: estimatedMinutes);

    // * Update route immediately - force rebuild
    if (mounted) {
      setState(() {
        _navigationRoute = List<LatLng>.from(
          updatedRoute,
        ); // * Create new list to force update
        _routeDistance = updatedDistanceKm;
        _routeDuration = updatedDuration;
      });
    }

    // * Refresh traveled/upcoming segments if navigation is active.
    _updateRouteSegments();
  }

  /// * Calculate route with custom start and end points
  Future<void> _calculateRouteWithCustomPoints(
    LatLng start,
    LatLng end,
    String mode,
  ) async {
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
        debugPrint(
          "⚠️ [MapScreen] GraphHopper unavailable, using fallback route",
        );
      }

      // * Check mounted again after async operation
      if (!mounted) return;

      if (_availableRoutes.isNotEmpty &&
          _selectedRouteIndex < _availableRoutes.length) {
        final route = _availableRoutes[_selectedRouteIndex];

        // * Validate route has points
        if (route.points.isEmpty || route.points.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Route has no points. Please try different locations.",
                ),
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
                content: const Text(
                  "Route calculated (GraphHopper unavailable). Route shown on map.",
                ),
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: const Center(child: Text("Invalid route data")),
                );
              }

              return RoutePreviewSheet(
                route: route,
                vehicleType: vehicleType,
                vehicleModeName: vehicleModeName,
                onSaveRoute:
                    _canCreateOrSaveRoutes
                        ? () {
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
                        }
                        : null,
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
                content: const Text(
                  "Route calculated. Tap 'Start' to begin navigation.",
                ),
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
      builder:
          (context) => SaveRouteDialog(
            routePoints: points,
            startPoint: startPoint,
            endPoint: endPoint,
            distanceMeters: totalDistance.round(),
            duration: Duration(
              seconds: (totalDistance / 50 * 3600).round(),
            ), // * Estimate: 50 km/h average
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
                  content: Text(
                    "Route loaded for editing. Tap on the route line to add control points. Tap a control point to move it.",
                  ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No route to save")));
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
    final duration =
        _routeDuration.inSeconds > 0
            ? _routeDuration
            : () {
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
              final minutes = ((distanceKm / avgSpeedKmh) * 60).round().clamp(
                1,
                24 * 60 * 7,
              );
              return Duration(minutes: minutes);
            }();

    showDialog(
      context: context,
      builder:
          (context) => SaveRouteDialog(
            routePoints: routePoints,
            startPoint: startPoint,
            endPoint: endPoint,
            distanceMeters: distanceMeters,
            duration: duration,
            vehicleType: vehicleType,
            onEditRoute:
                routePoints.length >= 2
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

    // * Return to a north-up map when leaving navigation.
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
    final x =
        math.cos(lat1) * math.sin(lat2) -
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
    final headingIsValid =
        heading != null && heading.isFinite && heading >= 0 && heading <= 360;
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
      final movedMeters = _calculateHaversineDistance(
        location,
        _lastSpeedLimitUpdateLocation!,
      );
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
    final next =
        hasAcceptedBefore ? _lerpLatLng(current, candidate, alpha) : candidate;
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
          builder:
              (context) => Container(
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: AppTheme.spacingMD),
                              Text(
                                "Pick a preset that matches your ride.",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: AppTheme.spacingLG),
                              // * Big Bike (400cc+)
                              _DirectionOption(
                                icon: Icons.motorcycle,
                                title: "Big Bike (400cc+)",
                                subtitle:
                                    "High displacement motorcycles, tolls optional",
                                isActive:
                                    _activeRoutingProfile ==
                                    'motorcycle_400plus',
                                onTap:
                                    () => _startNavigation(
                                      destination,
                                      'motorcycle_400plus',
                                    ),
                              ),
                              const SizedBox(height: AppTheme.spacingMD),
                              // * Motorcycle (≤399cc)
                              _DirectionOption(
                                icon: Icons.two_wheeler,
                                title: "Motorcycle (≤399cc)",
                                subtitle:
                                    "Standard motorcycles, automatically avoids toll roads",
                                isActive:
                                    _activeRoutingProfile ==
                                    'motorcycle_sub400',
                                onTap:
                                    () => _startNavigation(
                                      destination,
                                      'motorcycle_sub400',
                                    ),
                              ),
                              const SizedBox(height: AppTheme.spacingMD),
                              // * Car (Private)
                              _DirectionOption(
                                icon: Icons.directions_car,
                                title: "Car (Private)",
                                subtitle: "Fastest routes, tolls optional",
                                isActive: _activeRoutingProfile == 'car',
                                onTap:
                                    () => _startNavigation(destination, 'car'),
                              ),
                              const SizedBox(height: AppTheme.spacingMD),
                              // * Truck
                              _DirectionOption(
                                icon: Icons.local_shipping,
                                title: "Truck",
                                subtitle:
                                    "Commercial vehicles, respects truck ban hours",
                                isActive: _activeRoutingProfile == 'truck',
                                onTap:
                                    () =>
                                        _startNavigation(destination, 'truck'),
                              ),
                              const SizedBox(height: AppTheme.spacingMD),
                              // * Pedestrian
                              _DirectionOption(
                                icon: Icons.directions_walk,
                                title: "Pedestrian",
                                subtitle: "Walking routes, shortest paths",
                                isActive: _activeRoutingProfile == 'pedestrian',
                                onTap:
                                    () => _startNavigation(
                                      destination,
                                      'pedestrian',
                                    ),
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
      // * Drop a persistent pin.
      _setPinnedLocation(location: point, label: "Dropped Pin");

      // * Get address for the point using reverse geocoding
      // * Use a simple mock result for now (can enhance with reverse geocoding later)
      final mockResult = {
        'display_name':
            '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
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

  void _showMultiFuelUpdateDialog(FuelStation station) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return MultiFuelUpdateDialog(
          station: station,
          onSuccess: () {
            _onMapMoved();
          },
        );
      },
    );
  }

  void _showAddFuelStationDialog(LatLng location) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AddFuelStationDialog(
          location: location,
          onSuccess: () {
            _onMapMoved();
          },
        );
      },
    );
  }

  /// * Share location
  void _shareLocation(Map<String, dynamic> result, LatLng location) {
    // * TODO: Implement share functionality
    final shareText =
        "${result['display_name']}\n"
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
      debugPrint(
        "📍 [MapScreen] Location permission not granted, cannot start stream",
      );
      return;
    }

    // * Use more frequent updates for navigation, less frequent for normal mode
    final settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter:
          _isNavigating
              ? 1
              : 5, // * 1 meter for navigation, 5 meters for normal
    );

    await _positionSubscription?.cancel();
    // * Removed verbose logging to prevent console overflow

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        final rawUpdated = LatLng(position.latitude, position.longitude);
        final heading = position.heading;
        final headingIsValid =
            heading.isFinite && heading >= 0 && heading <= 360;
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
          _currentHeadingDegrees =
              headingIsValid ? heading : _currentHeadingDegrees;
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

          final speedKph =
              position.speed.isFinite ? (position.speed * 3.6) : null;

          setState(() {
            _distanceIndicators = indicators;
            _navigationHazardWarning = hazardWarning?.hazard;
            _navigationHazardDistanceMeters =
                hazardWarning?.distanceAheadMeters;
            _currentSpeedKph = speedKph;
          });

          // * Update speed limit in the background (best-effort).
          _updateSpeedLimitIfNeeded(
            location: updated,
            settings: navigationSettings,
          );

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

          // * Route weather alerting: sample weather ahead on-route (includes light rain).
          _checkWeatherAheadOnRouteIfNeeded(updated);

          // * Trigger rerouting if off-route
          if (isOffRoute && !_isRerouting) {
            _maybeTriggerRerouteWithConfirmation(
              title: "Off route",
              message:
                  "You seem to be off the planned route. Want to recalculate from your current location?",
            );
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

  bool _isRouteWeatherAlertsMuted() {
    final until = _routeWeatherAlertsMutedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  bool _isInRouteWeatherCooldown() {
    final until = _routeWeatherAlertCooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  WeatherData? _pickMoreSevereWeather(WeatherData? a, WeatherData? b) {
    if (a == null) return b;
    if (b == null) return a;

    int rank(WeatherState state) {
      switch (state) {
        case WeatherState.heavyRain:
          return 3;
        case WeatherState.lightRain:
          return 2;
        case WeatherState.intenseHeat:
          return 2;
        case WeatherState.cloudy:
          return 1;
        case WeatherState.sunny:
          return 0;
      }
    }

    final ra = rank(a.state);
    final rb = rank(b.state);
    if (ra != rb) return ra > rb ? a : b;

    // * Tie-breaker: prefer higher precipitation/temperature.
    final ap = a.precipitation ?? 0.0;
    final bp = b.precipitation ?? 0.0;
    if (ap != bp) return ap > bp ? a : b;
    return a.temperature >= b.temperature ? a : b;
  }

  bool _isDangerousRouteWeather(WeatherData data) {
    // * Per requirement: notify even at light rain.
    return data.state == WeatherState.lightRain ||
        data.state == WeatherState.heavyRain ||
        data.state == WeatherState.intenseHeat;
  }

  LatLng? _pointAlongRouteMeters({
    required List<LatLng> route,
    required List<double> cumulativeMeters,
    required double targetAlongMeters,
  }) {
    if (route.length < 2) return null;
    if (cumulativeMeters.length != route.length) return null;
    if (targetAlongMeters <= 0) return route.first;

    final total = cumulativeMeters.last;
    if (total <= 0) return route.last;
    final clampedTarget = targetAlongMeters.clamp(0.0, total);

    int idx = cumulativeMeters.indexWhere((m) => m >= clampedTarget);
    if (idx <= 0) {
      // * idx == 0 means target is at start; idx == -1 means beyond end.
      return idx == -1 ? route.last : route.first;
    }

    final prevMeters = cumulativeMeters[idx - 1];
    final nextMeters = cumulativeMeters[idx];
    final segmentMeters = (nextMeters - prevMeters).abs();
    if (segmentMeters <= 0.0) {
      return route[idx];
    }

    final t = ((clampedTarget - prevMeters) / segmentMeters).clamp(0.0, 1.0);
    final a = route[idx - 1];
    final b = route[idx];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  List<double> _routeWeatherSampleOffsetsMeters() {
    // * Keep calls low; WeatherService has caching (bucketed by ~0.02 degrees).
    return const [1000, 3000, 7000, 15000, 25000];
  }

  void _checkWeatherAheadOnRouteIfNeeded(LatLng currentLocation) {
    // * Fire-and-forget; guarded internally.
    _checkWeatherAheadOnRoute(currentLocation);
  }

  Future<void> _checkWeatherAheadOnRoute(LatLng currentLocation) async {
    if (!_isNavigating) return;
    if (_navigationRoute == null || _navigationRoute!.length < 2) return;
    if (_isRouteWeatherAlertsMuted()) return;
    if (_isInRouteWeatherCooldown()) return;
    if (_isRouteWeatherCheckInProgress) return;
    if (_isShowingRouteWeatherAlert) return;
    if (!_hasPreciseLocation) return;

    _ensureNavigationRouteCache();
    final route = _navigationRoute;
    final cumulativeMeters = _navigationRouteCumulativeMeters;
    if (route == null || cumulativeMeters == null) return;
    if (cumulativeMeters.length != route.length) return;

    final projection = _projectPointOntoRouteMeters(
      point: currentLocation,
      route: route,
      cumulativeMeters: cumulativeMeters,
    );
    if (projection == null) return;
    final currentAlong = projection["along"];
    if (currentAlong == null) return;

    // * Throttle checks by time and by route progress.
    final now = DateTime.now();
    final lastAt = _lastRouteWeatherCheckAt;
    final lastAlong = _lastRouteWeatherCheckAlongMeters;
    if (lastAt != null && now.difference(lastAt).inSeconds < 35) {
      return;
    }
    if (lastAlong != null && (currentAlong - lastAlong).abs() < 250) {
      return;
    }

    _isRouteWeatherCheckInProgress = true;
    _lastRouteWeatherCheckAt = now;
    _lastRouteWeatherCheckAlongMeters = currentAlong;

    try {
      WeatherData? earliestHit;
      double? earliestHitOffset;

      final offsets = _routeWeatherSampleOffsetsMeters();
      for (final offset in offsets) {
        // * If state changed while iterating, stop.
        if (!_isNavigating || !mounted) return;

        final samplePoint = _pointAlongRouteMeters(
          route: route,
          cumulativeMeters: cumulativeMeters,
          targetAlongMeters: currentAlong + offset,
        );
        if (samplePoint == null) continue;

        final data = await _weatherService.fetchWeatherData(
          center: samplePoint,
        );
        if (data == null) continue;

        if (_isDangerousRouteWeather(data)) {
          earliestHit =
              earliestHit == null
                  ? data
                  : _pickMoreSevereWeather(earliestHit, data);
          earliestHitOffset ??= offset.toDouble();

          // * Prefer earliest (closest) hazard; stop early for rain.
          if (data.state == WeatherState.lightRain ||
              data.state == WeatherState.heavyRain) {
            break;
          }
        }
      }

      if (earliestHit == null || earliestHitOffset == null) {
        return;
      }

      // * Don’t spam: if we’ve just shown a sheet, wait a bit.
      if (_isInRouteWeatherCooldown() || _isRouteWeatherAlertsMuted()) {
        return;
      }

      if (!mounted || !context.mounted) return;
      _isShowingRouteWeatherAlert = true;
      HapticFeedback.mediumImpact();
      await _showRouteWeatherAlertSheet(
        data: earliestHit,
        approxDistanceMetersAhead: earliestHitOffset,
      );
    } finally {
      _isRouteWeatherCheckInProgress = false;
      _isShowingRouteWeatherAlert = false;
    }
  }

  String _routeWeatherTitle(WeatherData data) {
    switch (data.state) {
      case WeatherState.lightRain:
        return "Light rain ahead";
      case WeatherState.heavyRain:
        return "Heavy rain ahead";
      case WeatherState.intenseHeat:
        return "Intense heat ahead";
      case WeatherState.cloudy:
        return "Weather change ahead";
      case WeatherState.sunny:
        return "Weather change ahead";
    }
  }

  String _routeWeatherSubtitle(WeatherData data, double metersAhead) {
    final kmAhead = metersAhead / 1000.0;
    final distanceText =
        kmAhead < 1.0
            ? "~${metersAhead.round()} m"
            : "~${kmAhead.toStringAsFixed(1)} km";

    final tempText = "${data.temperature.toStringAsFixed(0)}°C";
    final rainText =
        data.precipitation != null
            ? "${data.precipitation!.toStringAsFixed(1)} mm/h"
            : null;

    final details = <String>[tempText, if (rainText != null) rainText];
    return "$distanceText ahead • ${details.join(' • ')}";
  }

  Future<void> _showRouteWeatherAlertSheet({
    required WeatherData data,
    required double approxDistanceMetersAhead,
  }) async {
    // * Cooldown starts immediately (even if user dismisses).
    _routeWeatherAlertCooldownUntil = DateTime.now().add(
      const Duration(minutes: 2),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL),
            ),
            boxShadow: AppTheme.shadowLarge,
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMD,
                          ),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(
                          data.state == WeatherState.intenseHeat
                              ? Icons.thermostat
                              : Icons.cloudy_snowing,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _routeWeatherTitle(data),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppTheme.spacingXS),
                            Text(
                              _routeWeatherSubtitle(
                                data,
                                approxDistanceMetersAhead,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text(
                              "Weather can affect traction and visibility. Want to recalculate the route?",
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _routeWeatherAlertsMutedUntil = DateTime.now().add(
                              const Duration(minutes: 15),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Route weather alerts muted for 15 minutes",
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text("Mute 15 min"),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _maybeTriggerRerouteWithConfirmation(
                              title: "Weather ahead",
                              message:
                                  "Conditions ahead may affect safety. Want to recalculate the route from your current location?",
                            );
                          },
                          icon: const Icon(Icons.alt_route_rounded),
                          label: const Text("Recalculate"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingMD,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      // * Extend cooldown a bit so “continue” isn’t immediately re-prompted.
                      _routeWeatherAlertCooldownUntil = DateTime.now().add(
                        const Duration(minutes: 5),
                      );
                    },
                    child: const Text("Continue"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          _safeMoveMap(location, _mapZoom);
          debugPrint("📍 [MapScreen] Map moved to last known location");
          // * Detect country code when location is updated
          _detectCountryCode();
        } catch (e) {
          debugPrint("❌ [MapScreen] Error moving map: $e");
        }
      }

      // * Then get fresh position (await it to ensure we get location)
      try {
        final position = await locationService.getCurrentPosition(
          desiredAccuracy:
              kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
          preferCached: true,
        );
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

          // * Refine in background with higher precision without blocking UI.
          unawaited(() async {
            final precise = await locationService.getCurrentPosition(
              desiredAccuracy:
                  kIsWeb
                      ? LocationAccuracy.high
                      : LocationAccuracy.bestForNavigation,
              timeLimit: const Duration(seconds: 10),
              preferCached: false,
            );
            if (!mounted || precise == null) return;

            final refined = LatLng(precise.latitude, precise.longitude);
            final movedMeters = _calculateHaversineDistance(
              _currentLocation,
              refined,
            );
            if (movedMeters < 8) return;

            setState(() {
              _currentLocation = refined;
              _hasPreciseLocation = true;
            });

            if (!_isNavigating) {
              _safeMoveMap(refined, _mapZoom);
            }
          }());
        } else {
          debugPrint(
            "⚠️ [MapScreen] Could not get fresh location, using last known or default",
          );
          if (lastKnown == null && mounted) {
            // * Only use default if we have no location at all
            _safeMoveMap(_currentLocation, _mapZoom);
          }
        }
      } catch (e) {
        debugPrint("❌ [MapScreen] Error getting fresh location: $e");
        if (lastKnown == null && mounted) {
          _safeMoveMap(_currentLocation, _mapZoom);
        }
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error loading location: $e");
      // * Ensure we have a valid location
      if (mounted) {
        _currentLocation = LatLng(
          AppConstants.defaultLatitude,
          AppConstants.defaultLongitude,
        );
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textPrimary),
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
      final position = await locationService.getCurrentPosition(
        desiredAccuracy:
            kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
        preferCached: true,
      );

      if (position != null && mounted) {
        final location = LatLng(position.latitude, position.longitude);
        debugPrint(
          "📍 [MapScreen] Got location: ${location.latitude}, ${location.longitude}",
        );

        setState(() {
          _currentLocation = location;
        });

        // * Move map to location without changing current zoom.
        _safeMoveMap(location, _mapZoom);

        // * Refresh the provider
        ref.invalidate(currentLocationProvider);

        // * Background refinement to improve precision without delaying feedback.
        unawaited(() async {
          final precise = await locationService.getCurrentPosition(
            desiredAccuracy:
                kIsWeb
                    ? LocationAccuracy.high
                    : LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 10),
            preferCached: false,
          );
          if (!mounted || precise == null) return;

          final refined = LatLng(precise.latitude, precise.longitude);
          final movedMeters = _calculateHaversineDistance(
            _currentLocation,
            refined,
          );
          if (movedMeters < 8) return;

          setState(() {
            _currentLocation = refined;
            _hasPreciseLocation = true;
          });
          _safeMoveMap(refined, _mapZoom);
          ref.invalidate(currentLocationProvider);
        }());

        // * Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Location updated: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}",
              ),
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

      // * Fuel stations: use viewport bounds when available so panning shows stations in visible area
      final bounds = _mapVisibleBounds;
      if (!_isNavigating && bounds != null) {
        ref
            .read(mapFuelStationsProvider.notifier)
            .loadStationsInBounds(
              minLat: bounds.south,
              maxLat: bounds.north,
              minLon: bounds.west,
              maxLon: bounds.east,
              includeUnverified: true,
            );
      } else {
        ref
            .read(mapFuelStationsProvider.notifier)
            .loadStationsInBounds(
              minLat: _currentLocation.latitude - offset,
              maxLat: _currentLocation.latitude + offset,
              minLon: _currentLocation.longitude - offset,
              maxLon: _currentLocation.longitude + offset,
              includeUnverified: true,
            );
      }
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

      debugPrint(
        "🗺️ [MapScreen] Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}",
      );

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

      // * Fuel stations: use viewport bounds when not navigating so panning shows stations in visible area (e.g. Dolores)
      final bounds = _mapVisibleBounds;
      if (!_isNavigating && bounds != null) {
        ref
            .read(mapFuelStationsProvider.notifier)
            .loadStationsInBounds(
              minLat: bounds.south,
              maxLat: bounds.north,
              minLon: bounds.west,
              maxLon: bounds.east,
              includeUnverified: true,
            );
      } else {
        ref
            .read(mapFuelStationsProvider.notifier)
            .loadStationsInBounds(
              minLat: _currentLocation.latitude - offset,
              maxLat: _currentLocation.latitude + offset,
              minLon: _currentLocation.longitude - offset,
              maxLon: _currentLocation.longitude + offset,
              includeUnverified: true,
            );
      }
      _scheduleDynamicPoiRefresh();
      // * Removed verbose logging to prevent console overflow
    } catch (e, stackTrace) {
      debugPrint("❌ [MapScreen] ERROR in _onMapMoved: $e");
      debugPrint("❌ [MapScreen] Stack: $stackTrace");
    }
  }

  static const double _commuteBallSize = 56.0;
  static const double _commuteBallDefaultLeft = 16.0;
  static const double _commuteBallDefaultBottom = 180.0;

  Widget _buildCommuteBall(BuildContext context) {
    final isActive = ref.watch(isCommuteActiveProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final left = (_commuteBallLeft ?? _commuteBallDefaultLeft).clamp(
      0.0,
      screenWidth - _commuteBallSize,
    );
    final bottom = (_commuteBallBottom ?? _commuteBallDefaultBottom).clamp(
      80.0,
      screenHeight - 220.0,
    );

    // * Start 3s dim timer when visible and not dimmed (active or inactive)
    if (!_commuteBallDimmed && _commuteBallDimTimer == null) {
      _commuteBallDimTimer = Timer(_commuteBallDimDelay, () {
        if (mounted) {
          setState(() {
            _commuteBallDimmed = true;
            _commuteBallDimTimer = null;
          });
        }
      });
    }

    void onCommuteBallInteraction() {
      _commuteBallDimTimer?.cancel();
      _commuteBallDimTimer = null;
      if (_commuteBallDimmed && mounted) {
        setState(() => _commuteBallDimmed = false);
      }
    }

    Widget ball = GestureDetector(
      onTap: () {
        onCommuteBallInteraction();
        setState(() => _showCommuteOverlay = !_showCommuteOverlay);
      },
      onPanUpdate: (DragUpdateDetails d) {
        onCommuteBallInteraction();
        setState(() {
          _commuteBallLeft =
              (_commuteBallLeft ?? _commuteBallDefaultLeft) + d.delta.dx;
          _commuteBallBottom =
              (_commuteBallBottom ?? _commuteBallDefaultBottom) - d.delta.dy;
          _commuteBallLeft = _commuteBallLeft!.clamp(
            0.0,
            screenWidth - _commuteBallSize,
          );
          _commuteBallBottom = _commuteBallBottom!.clamp(
            80.0,
            screenHeight - 220.0,
          );
        });
      },
      child: Tooltip(
        message: isActive ? "Commute (active)" : "Commute",
        child: Material(
          color: isActive ? AppTheme.primaryColor : AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(_commuteBallSize / 2),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.3),
          child: SizedBox(
            width: _commuteBallSize,
            height: _commuteBallSize,
            child: Icon(
              isActive ? Icons.directions_bus : Icons.commute,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );

    if (_commuteBallDimmed) {
      ball = Opacity(opacity: 0.45, child: ball);
    }

    return Positioned(left: left, bottom: bottom, child: ball);
  }

  Widget _buildCommuteOverlay(BuildContext context) {
    final commuteState = ref.watch(commuteProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _showCommuteOverlay = false),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left: _commuteBallLeft ?? _commuteBallDefaultLeft,
            bottom:
                (_commuteBallBottom ?? _commuteBallDefaultBottom) +
                _commuteBallSize +
                8,
            child: SizedBox(
              width: 260,
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          commuteState.isActive
                              ? "Commuting to ${commuteState.destinationName ?? "destination"}"
                              : "Commute",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        if (commuteState.isActive) ...[
                          TextButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(commuteProvider.notifier)
                                  .stopCommute();
                              if (mounted)
                                setState(() => _showCommuteOverlay = false);
                            },
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                            ),
                            label: const Text("Stop commute"),
                          ),
                          const SizedBox(height: 4),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _showCommuteOverlay = false);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CommuteModeScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            commuteState.isActive
                                ? Icons.open_in_new
                                : Icons.directions_bus,
                            size: 20,
                          ),
                          label: Text(
                            commuteState.isActive
                                ? "Open commute"
                                : "Start commute",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // * Removed verbose build logging to prevent console overflow

    // * Don't build map until initialized
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    // * Removed verbose build logging to prevent console overflow

    // * When another tab (e.g. Fuel) selects a station for directions, show the sheet
    ref.listen<FuelStation?>(selectedFuelStationProvider, (prev, next) {
      if (next != null && mounted && !_isNavigating) {
        setState(() => _selectedFuelStation = next);
      }
    });

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
          debugPrint(
            "❌ [MapScreen] ERROR reading mapHazardsProvider.notifier: $e",
          );
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
      if (!_currentLocation.latitude.isFinite ||
          !_currentLocation.longitude.isFinite) {
        _currentLocation = LatLng(
          AppConstants.defaultLatitude,
          AppConstants.defaultLongitude,
        );
      }

      // * Create a safe location object with explicit validation
      final safeLat =
          _currentLocation.latitude.isFinite
              ? _currentLocation.latitude
              : AppConstants.defaultLatitude;
      final safeLon =
          _currentLocation.longitude.isFinite
              ? _currentLocation.longitude
              : AppConstants.defaultLongitude;
      final safeCenter = LatLng(safeLat, safeLon);
      final currentLocationForMarker =
          _hasPreciseLocation ? _currentLocation : null;
      final navigationSettings = ref.watch(navigationSettingsProvider);
      final mapZoom = _mapZoom;
      final showRecents =
          _searchController.text.trim().isEmpty &&
          (_recentLocations.isNotEmpty || _isLoadingRecents);
      final selectedPlaceRecentMatch =
          _selectedPlace == null
              ? null
              : _findRecentMatchForPlace(_selectedPlace!);
      final fuelStationsAsync = ref.watch(mapFuelStationsProvider);
      final fuelStations =
          fuelStationsAsync.valueOrNull ?? const <FuelStation>[];
      final showKnownPlaces = !_isNavigating && mapZoom >= _knownPlacesMinZoom;
      final showDynamicPois = !_isNavigating && mapZoom >= _dynamicPoisMinZoom;
      final showFuelStations = !_isNavigating && mapZoom >= 10.0;
      final showHazardMarkers = mapZoom >= _knownPlacesMinZoom;
      final showHoaMarkers = !_isNavigating && mapZoom >= 13.0;

      // * Listen to route creation trigger
      ref.listen<RouteCreationAction?>(routeCreationTriggerProvider, (
        previous,
        next,
      ) {
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
                        (event is MapEventMoveStart &&
                            event.source == MapEventSource.dragStart) ||
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
                      if (!_isLoadingDynamicPois) {
                        _loadDynamicPoisForViewport();
                      }
                      _onMapMoved();
                    } catch (e, stackTrace) {
                      debugPrint(
                        "❌ [MapScreen] Error in onMapMoved callback: $e",
                      );
                      debugPrint("❌ [MapScreen] Stack: $stackTrace");
                    }
                  }
                },
                onTap: (tapPosition, point) {
                  // * Handle custom point selection for navigation
                  // * Also check if we have points set but state was lost (e.g., after minimizing)
                  if (_isSelectingCustomPoints ||
                      (_customStartPoint != null && _customEndPoint == null)) {
                    // * Restore state if it was lost
                    if (!_isSelectingCustomPoints) {
                      setState(() {
                        _isSelectingCustomPoints = true;
                        _selectingStartPoint =
                            false; // * We have start, so selecting end
                      });
                    }

                    final wasSelectingStart =
                        _selectingStartPoint; // * Remember before state change
                    final bool justSetEndPoint =
                        !_selectingStartPoint && _customEndPoint == null;

                    setState(() {
                      if (_selectingStartPoint) {
                        _customStartPoint = point;
                        _selectingStartPoint =
                            false; // * Switch to selecting end point
                      } else {
                        _customEndPoint = point;
                      }
                      // * Ensure state is maintained
                      _isSelectingCustomPoints = true;
                    });

                    // * Auto-calculate route when end point is selected (after setState)
                    // * Close dialog first, then calculate route
                    if (justSetEndPoint &&
                        _customStartPoint != null &&
                        _customEndPoint != null) {
                      // * Close any open dialogs/sheets first
                      if (mounted) {
                        try {
                          // * Try to close modal bottom sheet if open
                          final navigator = Navigator.of(
                            context,
                            rootNavigator: false,
                          );
                          if (navigator.canPop()) {
                            navigator.pop();
                          }
                        } catch (e) {
                          // * Ignore if dialog already closed
                        }
                      }

                      // * Wait a moment for dialog to close, then calculate route
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted &&
                            _customStartPoint != null &&
                            _customEndPoint != null) {
                          setState(() {
                            _isSelectingCustomPoints = false;
                          });
                          _calculateRouteWithCustomPoints(
                            _customStartPoint!,
                            _customEndPoint!,
                            'car',
                          );
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
                          if (_customStartPoint == null ||
                              _customEndPoint == null) {
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
                      final distance = _calculateDistance(
                        point,
                        _routeControlPoints[i],
                      );
                      if (distance < minDistance) {
                        minDistance = distance;
                        nearestIndex = i;
                      }
                    }

                    // * If within 100 meters of a control point, move it
                    if (nearestIndex >= 0 && minDistance < 0.1) {
                      // * 100 meters
                      // * Move control point to tap location
                      setState(() {
                        _routeControlPoints[nearestIndex] = point;
                      });

                      // * Update route immediately (synchronous for instant visual feedback)
                      if (_navigationRoute != null &&
                          _navigationRoute!.isNotEmpty) {
                        _updateRouteGeometryWithControlPoints();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Control point moved. Route updated.",
                              ),
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
                  if (_isEditingRoute &&
                      _navigationRoute != null &&
                      _navigationRoute!.isNotEmpty) {
                    // * Find nearest point on route line
                    final nearestPoint = _findNearestRoutePoint(point);
                    if (nearestPoint != null) {
                      // * Add control point at this location
                      setState(() {
                        _routeControlPoints.add(nearestPoint);
                      });

                      // * Update route immediately to show the bend
                      if (_navigationRoute != null &&
                          _navigationRoute!.isNotEmpty) {
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
                        _selectedFuelStation = null;
                        _pinnedLocation = null;
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
                        const SnackBar(
                          content: Text("Please draw at least 2 points"),
                        ),
                      );
                    }
                    return;
                  }

                  // * Handle route editing - long press on route line to add control point
                  if (_isEditingRoute &&
                      _navigationRoute != null &&
                      _navigationRoute!.isNotEmpty) {
                    final nearestPoint = _findNearestRoutePoint(point);
                    if (nearestPoint != null) {
                      setState(() {
                        _routeControlPoints.add(nearestPoint);
                      });

                      // * Update route immediately to show the bend
                      if (_navigationRoute != null &&
                          _navigationRoute!.isNotEmpty) {
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
                  userAgentPackageName:
                      "com.smartroad.app", // * Package name stays lowercase (technical identifier)
                  maxZoom: 19,
                  // * Enable tile wrapping for infinite horizontal scrolling
                  // * flutter_map handles wrapping automatically for Epsg3857 (Web Mercator)
                  // * Tiles will wrap horizontally when panning left/right
                ),
                // * Traffic layer (above base map, below weather)
                Consumer(
                  builder: (context, ref, child) {
                    final filterState = ref.watch(mapFilterProvider);
                    if (!filterState.showTraffic) {
                      return const SizedBox.shrink();
                    }

                    if (!TrafficConfig.isAvailable) {
                      // * Do not mount the layer when no key is configured.
                      return const SizedBox.shrink();
                    }

                    return TrafficLayer(enabled: true, opacity: 0.7);
                  },
                ),
                // * Weather tile layers (above base map, below routes)
                // * On web, only available if backend proxy is configured (see WEATHER_LAYERS_TROUBLESHOOTING.md)
                // * On other platforms, always available
                if (WeatherConfig.areLayersAvailable &&
                    _weatherLayerManager
                        .getLayerConfig(WeatherLayerType.rain)
                        .enabled)
                  RainLayer(manager: _weatherLayerManager),
                if (WeatherConfig.areLayersAvailable &&
                    _weatherLayerManager
                        .getLayerConfig(WeatherLayerType.heat)
                        .enabled)
                  HeatLayer(manager: _weatherLayerManager),
                if (WeatherConfig.areLayersAvailable &&
                    _weatherLayerManager
                        .getLayerConfig(WeatherLayerType.clouds)
                        .enabled)
                  CloudLayer(manager: _weatherLayerManager),
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
                  if (_isNavigating &&
                      (_traveledRoute.isNotEmpty || _upcomingRoute.isNotEmpty))
                    PolylineLayer(
                      polylines: [
                        // * Traveled route (light blue)
                        if (_traveledRoute.isNotEmpty)
                          Polyline(
                            points: _traveledRoute,
                            strokeWidth: 6.0,
                            color: _getRouteColor(
                              _navigationMode ?? 'car',
                            ).withOpacity(0.3),
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.white.withOpacity(0.4),
                          ),
                        // * Upcoming route (full blue)
                        if (_upcomingRoute.isNotEmpty)
                          Polyline(
                            points: _upcomingRoute,
                            strokeWidth: 6.0,
                            color:
                                _isOffRoute
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
                          strokeWidth:
                              _isEditingRoute
                                  ? 8.0
                                  : 6.0, // * Thicker when editing
                          color:
                              _isEditingRoute
                                  ? AppTheme.primaryColor.withOpacity(
                                    0.9,
                                  ) // * More visible when editing
                                  : _getRouteColor(_navigationMode ?? 'car'),
                          borderStrokeWidth: _isEditingRoute ? 3.0 : 2.0,
                          borderColor:
                              _isEditingRoute
                                  ? Colors.white.withOpacity(
                                    0.9,
                                  ) // * More visible border when editing
                                  : Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                // * Custom start/end point markers (when selecting) - Always show if points are set
                if (_isSelectingCustomPoints ||
                    _customStartPoint != null ||
                    _customEndPoint != null) ...[
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
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 28,
                            ),
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
                            child: const Icon(
                              Icons.flag,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                // * Draggable route control points (when editing route)
                if (_isEditingRoute && _routeControlPoints.isNotEmpty)
                  MarkerLayer(
                    markers:
                        _routeControlPoints.asMap().entries.map((entry) {
                          final index = entry.key;
                          final controlPoint = entry.value;
                          return Marker(
                            point: controlPoint,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    _draggingControlPointIndex == index
                                        ? AppTheme.primaryColor
                                        : AppTheme.warningColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
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
                            border: Border.all(color: Colors.white, width: 3),
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

                // * Dropped pin marker (persists until replaced).
                if (_pinnedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pinnedLocation!,
                        width: 40,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 42,
                              color: AppTheme.errorColor,
                            ),
                          ],
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
                    markers:
                        _filterOverlappingMarkers<Place>(
                          markers:
                              _knownPlaces.where((place) {
                                final nearDynamicFuel =
                                    showDynamicPois &&
                                    _dynamicPois.any((poi) {
                                      final category =
                                          (poi.category ?? poi.type ?? "")
                                              .toLowerCase();
                                      if (category != 'fuel') return false;
                                      return _calculateHaversineDistance(
                                            place.location,
                                            poi.location,
                                          ) <
                                          520;
                                    });
                                if (nearDynamicFuel) return false;

                                final nearFuelStation =
                                    showFuelStations &&
                                    fuelStations.any(
                                      (station) =>
                                          _calculateHaversineDistance(
                                            place.location,
                                            station.location,
                                          ) <
                                          520,
                                    );
                                return !nearFuelStation;
                              }).toList(),
                          getLocation: (p) => p.location,
                          getWidth: (p) {
                            final showLabel =
                                mapZoom >= 12.0 || _selectedPlace?.id == p.id;
                            return showLabel ? 200.0 : 40.0;
                          },
                          minPixelSpacing:
                              60.0, // * Minimum 60px spacing between known place markers
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
                          final showLabel =
                              mapZoom >= 12.0 ||
                              _selectedPlace?.id ==
                                  place.id; // * Show labels earlier (was 14.0)
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
                    markers:
                        () {
                          // * Filter overlapping markers, preserving original index for label visibility
                          final filtered = _filterOverlappingMarkers<MapPoi>(
                            markers: _dynamicPois,
                            getLocation: (p) => p.location,
                            getWidth: (p) {
                              final originalIndex = _dynamicPois.indexOf(p);
                              final category =
                                  (p.category ?? p.type ?? "").toLowerCase();
                              // * Always show labels for fuel POIs (gas stations) so they are discoverable.
                              final showLabel =
                                  category == "fuel" ||
                                  (mapZoom >= 15.0 && originalIndex < 15);
                              return showLabel ? 200.0 : 40.0;
                            },
                            minPixelSpacing: 20.0, // * Keep more POIs visible
                            zoom: mapZoom,
                          );
                          return filtered;
                        }().asMap().entries.map((entry) {
                          final poi = entry.value;
                          final originalIndex = _dynamicPois.indexOf(
                            poi,
                          ); // * Get original index for label logic
                          // * Category is now a clean string from OverpassPoiService
                          // * (e.g. 'hospital', 'school', 'fuel', 'restaurant', etc.)
                          final category =
                              (poi.category ?? poi.type ?? '').toLowerCase();
                          final icon = switch (category) {
                            'mall' ||
                            'supermarket' ||
                            'shop' => Icons.storefront_outlined,
                            'terminal' => Icons.directions_bus_filled,
                            'hospital' => Icons.local_hospital_outlined,
                            'school' => Icons.school_outlined,
                            'fuel' => Icons.local_gas_station_outlined,
                            'bank' => Icons.account_balance_outlined,
                            'atm' => Icons.atm_outlined,
                            'pharmacy' => Icons.local_pharmacy_outlined,
                            'restaurant' => Icons.restaurant_outlined,
                            'hotel' => Icons.hotel_outlined,
                            'museum' => Icons.museum_outlined,
                            'attraction' => Icons.attractions_outlined,
                            'park' => Icons.park_outlined,
                            'sports' => Icons.sports_soccer_outlined,
                            'airport' => Icons.local_airport_outlined,
                            'police' => Icons.local_police_outlined,
                            'fire_station' =>
                              Icons.local_fire_department_outlined,
                            'library' => Icons.local_library_outlined,
                            'entertainment' => Icons.theaters_outlined,
                            'worship' => Icons.church_outlined,
                            'parking' => Icons.local_parking_outlined,
                            'post_office' => Icons.local_post_office_outlined,
                            'market' => Icons.storefront_outlined,
                            _ => Icons.place_outlined,
                          };

                          final accentColor = switch (category) {
                            'mall' ||
                            'supermarket' ||
                            'shop' ||
                            'market' => AppTheme.primaryColor,
                            'terminal' || 'airport' => AppTheme.infoColor,
                            'hospital' || 'pharmacy' => AppTheme.errorColor,
                            'school' => AppTheme.secondaryColor,
                            'fuel' => AppTheme.warningColor,
                            'bank' || 'atm' => const Color(0xFF1565C0),
                            'restaurant' => const Color(0xFF2E7D32),
                            'hotel' => const Color(0xFF6A1B9A),
                            'museum' || 'attraction' => const Color(0xFF00695C),
                            'park' || 'sports' => const Color(0xFF388E3C),
                            'police' || 'fire_station' => AppTheme.errorColor,
                            'worship' => const Color(0xFF5D4037),
                            _ => AppTheme.textSecondary,
                          };

                          // * Show labels based on zoom tier and POI prominence.
                          final showLabel =
                              category == 'fuel' ||
                              (mapZoom >= 12.0 && originalIndex < 32) ||
                              (mapZoom >= 14.0 && originalIndex < 55);
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
                                  if (category == 'fuel') {
                                    _selectedFuelStation = FuelStation(
                                      id: poi.id,
                                      name: poi.name,
                                      latitude: poi.latitude,
                                      longitude: poi.longitude,
                                      brand: null,
                                      province: "",
                                      city: "",
                                      region: null,
                                      verified: false,
                                      source: "osm",
                                      prices:
                                          RegionalFuelDefaults.getDefaultPricesForStation(
                                            "",
                                            null,
                                          ),
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    );
                                    _selectedPlace = null;
                                  } else {
                                    // * Show the same place preview UI for non-fuel dynamic POIs.
                                    _selectedPlace = communityPlace;
                                    _selectedFuelStation = null;
                                  }
                                  _selectedHazard = null;
                                  _showSearchResults = false;
                                });
                                _searchFocusNode.unfocus();
                              },
                            ),
                          );
                        }).toList(),
                  ),
                if (showFuelStations && fuelStations.isNotEmpty)
                  MarkerLayer(
                    markers:
                        fuelStations.map((station) {
                          final isUnverifiedCommunity =
                              !station.verified &&
                              station.source == "community";
                          return Marker(
                            point: station.location,
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () {
                                if (!mounted) return;
                                setState(() {
                                  _selectedFuelStation = station;
                                  _selectedPlace = null;
                                  _selectedHazard = null;
                                  _showSearchResults = false;
                                });
                                _searchFocusNode.unfocus();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      isUnverifiedCommunity
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.secondary
                                          : AppTheme.warningColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.local_gas_station,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                // * Hazard markers
                if (showHazardMarkers)
                  MarkerLayer(
                    markers:
                        hazards
                            .where(
                              (hazard) =>
                                  hazard.latitude.isFinite &&
                                  hazard.longitude.isFinite &&
                                  hazard.latitude != 0.0 &&
                                  hazard.longitude != 0.0,
                            )
                            .map((hazard) {
                              return Marker(
                                point: LatLng(
                                  hazard.latitude,
                                  hazard.longitude,
                                ),
                                width: 34,
                                height: 34,
                                child: GestureDetector(
                                  onTap: () {
                                    if (mounted) {
                                      setState(() {
                                        _selectedHazard = hazard;
                                        _selectedPlace = null;
                                        _selectedFuelStation = null;
                                      });
                                    }
                                  },
                                  child: HazardMarker(hazard: hazard),
                                ),
                              );
                            })
                            .toList(),
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
                        (currentZoom + 1).clamp(
                          AppConstants.minZoom,
                          AppConstants.maxZoom,
                        ),
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
                        (currentZoom - 1).clamp(
                          AppConstants.minZoom,
                          AppConstants.maxZoom,
                        ),
                      );
                    },
                    tooltip: "Zoom out",
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * Location Button
                  _MapControlButton(
                    icon:
                        _isNavigating
                            ? (_isNavigationFollowing
                                ? Icons.navigation
                                : Icons.my_location)
                            : Icons.gps_fixed,
                    onPressed:
                        _hasPreciseLocation
                            ? () {
                              if (_isNavigating) {
                                // * Re-center and resume follow mode.
                                _recenterNavigationCamera();
                                return;
                              }

                              // * Center on current location
                              _safeMoveMap(_currentLocation, _mapZoom);
                            }
                            : _requestLocationPermission,
                    tooltip:
                        _hasPreciseLocation
                            ? (_isNavigating
                                ? (_isNavigationFollowing
                                    ? "Following route"
                                    : "Re-center")
                                : "Center on my location")
                            : "Get my location",
                    backgroundColor:
                        _hasPreciseLocation
                            ? (_isNavigating && !_isNavigationFollowing
                                ? AppTheme.warningColor
                                : AppTheme.primaryColor)
                            : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  _MapControlButton(
                    icon: Icons.local_gas_station_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FuelPricesScreen(),
                        ),
                      );
                    },
                    tooltip: "Fuel prices",
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
                child: AnimatedContainer(
                  duration: AppTheme.animationFast,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(color: AppTheme.borderColor, width: 1.5),
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
                          prefixIcon:
                              _isSearching
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
                                    _showRecentsOverlay();
                                  },
                                  tooltip: "Clear",
                                ),
                              if (_recentLocations.isNotEmpty)
                                Tooltip(
                                  message:
                                      "Recent searches: ${_recentSummaryLabel()}",
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingSM,
                                      vertical: AppTheme.spacingXS,
                                    ),
                                    margin: const EdgeInsets.only(
                                      right: AppTheme.spacingSM,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoColor.withOpacity(
                                        0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSM,
                                      ),
                                    ),
                                    child: Text(
                                      _recentSummaryLabel(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              Tooltip(
                                message: "Hazards in view: ${hazards.length}",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSM,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  margin: const EdgeInsets.only(
                                    right: AppTheme.spacingSM,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM,
                                    ),
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
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
                                  final filterState = ref.watch(
                                    mapFilterProvider,
                                  );
                                  return IconButton(
                                    icon: Stack(
                                      children: [
                                        Icon(
                                          Icons.filter_list,
                                          color:
                                              filterState.hasActiveFilters
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
                          if (value.trim().isEmpty) {
                            _showRecentsOverlay();
                            return;
                          }
                          // * Debounce search
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_searchController.text == value &&
                                value.isNotEmpty) {
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
                          if (_searchController.text.trim().isEmpty) {
                            _showRecentsOverlay();
                            return;
                          }
                          if (_searchResults.isNotEmpty) {
                            setState(() {
                              _showSearchResults = true;
                            });
                          }
                        },
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child:
                            _isLoadingDynamicPois
                                ? const LinearProgressIndicator(
                                  key: ValueKey("poi-loading"),
                                  minHeight: 2,
                                  color: AppTheme.primaryColor,
                                  backgroundColor: Colors.transparent,
                                )
                                : const SizedBox.shrink(
                                  key: ValueKey("poi-idle"),
                                ),
                      ),
                      // * Search Results Dropdown
                      // * Wrap with a GestureDetector to ensure taps inside the dropdown
                      // * don't get interpreted as map taps (which would close the dropdown).
                      if (_showSearchResults &&
                          (_searchResults.isNotEmpty || showRecents))
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            // * Intentionally no-op: absorbs clicks within the dropdown.
                          },
                          child: Container(
                            margin: const EdgeInsets.only(
                              top: AppTheme.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
                              border: Border.all(
                                color: AppTheme.borderColor,
                                width: 1.5,
                              ),
                              boxShadow: AppTheme.shadowLarge,
                            ),
                            constraints: BoxConstraints(
                              maxHeight: _getSearchResultsDropdownMaxHeight(
                                context,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showRecents)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppTheme.spacingMD,
                                      AppTheme.spacingSM,
                                      AppTheme.spacingMD,
                                      AppTheme.spacingSM,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.history,
                                              size: 16,
                                              color: AppTheme.infoColor,
                                            ),
                                            const SizedBox(
                                              width: AppTheme.spacingXS,
                                            ),
                                            Text(
                                              "Recent searches",
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelLarge?.copyWith(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _recentSummaryLabel(),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall?.copyWith(
                                                color: AppTheme.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingSM,
                                        ),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              ActionChip(
                                                label: const Text(
                                                  'Restaurants',
                                                ),
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  _openCategoryPoiSearch(
                                                    title: 'Restaurants',
                                                    query: 'restaurant',
                                                    icon: Icons.restaurant,
                                                  );
                                                },
                                              ),
                                              const SizedBox(
                                                width: AppTheme.spacingSM,
                                              ),
                                              ActionChip(
                                                label: const Text('Hotels'),
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  _openCategoryPoiSearch(
                                                    title: 'Hotels',
                                                    query: 'hotel',
                                                    icon: Icons.hotel,
                                                  );
                                                },
                                              ),
                                              const SizedBox(
                                                width: AppTheme.spacingSM,
                                              ),
                                              ActionChip(
                                                label: const Text('Gas'),
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  _openCategoryPoiSearch(
                                                    title: 'Gas stations',
                                                    query: 'gas station',
                                                    icon:
                                                        Icons.local_gas_station,
                                                  );
                                                },
                                              ),
                                              const SizedBox(
                                                width: AppTheme.spacingSM,
                                              ),
                                              ActionChip(
                                                label: const Text('ATM'),
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  _openCategoryPoiSearch(
                                                    title: 'ATMs',
                                                    query: 'atm',
                                                    icon: Icons.atm,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Flexible(
                                  child:
                                      showRecents
                                          ? ListView.separated(
                                            shrinkWrap: true,
                                            itemCount:
                                                _isLoadingRecents
                                                    ? (_recentLocations.isEmpty
                                                        ? 1
                                                        : _recentLocations
                                                            .length)
                                                    : _recentLocations.length,
                                            separatorBuilder:
                                                (context, index) => Divider(
                                                  height: 1,
                                                  color: AppTheme.borderColor,
                                                ),
                                            itemBuilder: (context, index) {
                                              if (_isLoadingRecents &&
                                                  _recentLocations.isEmpty) {
                                                return ListTile(
                                                  leading: const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            AppTheme
                                                                .primaryColor,
                                                          ),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    "Loading recent locations…",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color:
                                                              AppTheme
                                                                  .textSecondary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  dense: true,
                                                );
                                              }

                                              final recent =
                                                  _recentLocations[index];
                                              final leadingIcon =
                                                  recent.kind ==
                                                          RecentLocationKind
                                                              .navigation
                                                      ? Icons.navigation
                                                      : Icons.history;

                                              return ListTile(
                                                leading: Icon(
                                                  leadingIcon,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                title: Text(
                                                  recent.label,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            AppTheme
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                trailing: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal:
                                                            AppTheme.spacingSM,
                                                        vertical:
                                                            AppTheme.spacingXS,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.infoColor
                                                        .withOpacity(0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTheme.radiusSM,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    _formatRecentAge(
                                                      recent.updatedAt,
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color:
                                                              AppTheme
                                                                  .textPrimary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                                onTap: () async {
                                                  // * Re-promote recent to the top.
                                                  try {
                                                    final updated =
                                                        await _preferencesService
                                                            .addRecentLocation(
                                                              label:
                                                                  recent.label,
                                                              latitude:
                                                                  recent
                                                                      .latitude,
                                                              longitude:
                                                                  recent
                                                                      .longitude,
                                                              kind: recent.kind,
                                                            );
                                                    if (mounted) {
                                                      setState(() {
                                                        _recentLocations =
                                                            updated;
                                                      });
                                                    }
                                                  } catch (_) {}

                                                  _selectSearchResult(
                                                    _recentToSearchResultMap(
                                                      recent,
                                                    ),
                                                  );
                                                },
                                                dense: true,
                                              );
                                            },
                                          )
                                          : ListView.separated(
                                            shrinkWrap: true,
                                            itemCount: _visibleSearchResults
                                                .clamp(
                                                  0,
                                                  _searchResults.length,
                                                ),
                                            separatorBuilder:
                                                (context, index) => Divider(
                                                  height: 1,
                                                  color: AppTheme.borderColor,
                                                ),
                                            itemBuilder: (context, index) {
                                              final result =
                                                  _searchResults[index];
                                              final resultKey =
                                                  "${result['lat']}_${result['lon']}";
                                              final distance =
                                                  _searchResultDistances[resultKey];
                                              final isLoading =
                                                  _searchResultDistanceLoading[resultKey] ??
                                                  false;

                                              return ListTile(
                                                leading: Icon(
                                                  Icons.place,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                title: Text(
                                                  result['display_name'] ??
                                                      'Unknown location',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            AppTheme
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle:
                                                    result['address'] != null
                                                        ? Text(
                                                          _formatAddress(
                                                            result['address']
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >,
                                                          ),
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color:
                                                                    AppTheme
                                                                        .textSecondary,
                                                              ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        )
                                                        : null,
                                                trailing:
                                                    distance != null
                                                        ? Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              _formatDistance(
                                                                distance,
                                                              ),
                                                              style: Theme.of(
                                                                    context,
                                                                  )
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color:
                                                                        AppTheme
                                                                            .primaryColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                            if (isLoading) ...[
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                                height: 12,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  valueColor:
                                                                      AlwaysStoppedAnimation<
                                                                        Color
                                                                      >(
                                                                        AppTheme
                                                                            .primaryColor,
                                                                      ),
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
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(
                                                                  AppTheme
                                                                      .primaryColor,
                                                                ),
                                                          ),
                                                        )
                                                        : null,
                                                onTap:
                                                    () => _selectSearchResult(
                                                      result,
                                                    ),
                                                dense: true,
                                              );
                                            },
                                          ),
                                ),
                                // * Show More button if there are more results
                                if (!showRecents &&
                                    _visibleSearchResults <
                                        _searchResults.length)
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          // * Expand dropdown and reveal all results at once.
                                          _visibleSearchResults =
                                              _searchResults.length;

                                          // * Keep dropdown visible (especially on web where clicks
                                          // * can sometimes be interpreted as map taps).
                                          _showSearchResults = true;
                                        });
                                      },
                                      dense: true,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // * Navigation overlay (when navigating)
            if (_isNavigating &&
                _navigationDestination != null &&
                _navigationMode != null) ...[
              Positioned(
                top: AppTheme.spacingMD,
                left: AppTheme.spacingMD,
                right: AppTheme.spacingMD,
                child: _NavigationOverlay(
                  mode: _navigationMode!,
                  destination: _navigationDestination!,
                  onStop: _stopNavigation,
                  onChangeRoute:
                      _availableRoutes.length > 1
                          ? _showRouteSelectionSheet
                          : null,
                  onSaveRoute:
                      _canCreateOrSaveRoutes ? _showSaveRouteDialog : null,
                  remainingDistance:
                      _remainingDistance > 0 ? _remainingDistance / 1000 : null,
                  remainingDuration: _remainingDuration,
                  isOffRoute: _isOffRoute,
                ),
              ),
              // * Speed HUD (driver-focused)
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
              // * Hazard warning banner (on-route alerts)
              if (_navigationHazardWarning != null &&
                  _navigationHazardDistanceMeters != null)
                Positioned(
                  top:
                      (_distanceIndicators != null &&
                              _distanceIndicators!.hasAny)
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
                        _navigationHazardMutedUntil[hazardId] = DateTime.now()
                            .add(const Duration(minutes: 5));
                        _navigationHazardWarning = null;
                        _navigationHazardDistanceMeters = null;
                      });
                    },
                    onTap: () {
                      if (!mounted || _navigationHazardWarning == null) return;
                      setState(() {
                        _selectedHazard = _navigationHazardWarning;
                        _selectedPlace = null;
                        _selectedFuelStation = null;
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
                  isRecentlySearched: selectedPlaceRecentMatch != null,
                  recentSearchMeta:
                      selectedPlaceRecentMatch == null
                          ? null
                          : _formatRecentAge(
                            selectedPlaceRecentMatch.updatedAt,
                          ),
                  onGetDirections: () {
                    final destination = _selectedPlace!.location;
                    if (mounted) {
                      setState(() => _selectedPlace = null);
                    }
                    _openDirections(destination);
                  },
                  onCommuteToLocation:
                      _selectedPlace!.latitude.isNaN ||
                              _selectedPlace!.longitude.isNaN
                          ? null
                          : () {
                            final place = _selectedPlace!;
                            if (mounted) {
                              setState(() => _selectedPlace = null);
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CommuteModeScreen(),
                                settings: RouteSettings(
                                  arguments: <String, dynamic>{
                                    "destinationName": place.name,
                                    "lat": place.latitude,
                                    "lon": place.longitude,
                                  },
                                ),
                              ),
                            );
                          },
                  onClose: () {
                    if (mounted) {
                      setState(() => _selectedPlace = null);
                    }
                  },
                ),
              ),
            if (_selectedFuelStation != null && !_isNavigating)
              Align(
                alignment: Alignment.bottomCenter,
                child: FuelStationDetailSheet(
                  station: _selectedFuelStation!,
                  onGetDirections: () {
                    final destination = _selectedFuelStation!.location;
                    if (mounted) {
                      setState(() => _selectedFuelStation = null);
                    }
                    _openDirections(destination);
                  },
                  onCommuteToLocation: () {
                    final station = _selectedFuelStation!;
                    if (mounted) {
                      setState(() => _selectedFuelStation = null);
                      ref
                          .read(selectedFuelStationProvider.notifier)
                          .clearSelection();
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CommuteModeScreen(),
                        settings: RouteSettings(
                          arguments: <String, dynamic>{
                            "destinationName": station.name,
                            "lat": station.latitude,
                            "lon": station.longitude,
                          },
                        ),
                      ),
                    );
                  },
                  onClose: () {
                    if (mounted) {
                      setState(() => _selectedFuelStation = null);
                      ref
                          .read(selectedFuelStationProvider.notifier)
                          .clearSelection();
                    }
                  },
                  onUpdatePrices: () {
                    final station = _selectedFuelStation;
                    if (station == null) return;
                    _showMultiFuelUpdateDialog(station);
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
                                      onPressed:
                                          _recalculateRouteWithControlPoints,
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text("Recalculate"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _routeControlPoints.clear();
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Control points cleared",
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.clear_all, size: 18),
                                    label: const Text("Clear"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_routeControlPoints.isNotEmpty)
                              const SizedBox(height: 8),
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Route editing mode disabled",
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text("Done"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
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
            // * Draggable commute ball with active state and minimal overlay
            if (!_isNavigating) _buildCommuteBall(context),
            if (_showCommuteOverlay) _buildCommuteOverlay(context),
            // * Music Control Widget (compact mini-player)
            Positioned(
              bottom: 110, // * Above bottom navigation
              left: AppTheme.spacingMD,
              child: const MusicControlWidget(),
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
                Icon(Icons.map_outlined, size: 64, color: AppTheme.errorColor),
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
        final validHOAs =
            hoas
                .where(
                  (hoa) =>
                      hoa.latitude != null &&
                      hoa.longitude != null &&
                      hoa.latitude!.isFinite &&
                      hoa.longitude!.isFinite &&
                      hoa.latitude != 0.0 &&
                      hoa.longitude != 0.0,
                )
                .toList();

        if (validHOAs.isEmpty) {
          return const SizedBox.shrink();
        }

        return MarkerLayer(
          markers:
              validHOAs.map((hoa) {
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
    LatLng point, {
    double thresholdKm = 1.0,
  }) {
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
  double _calculateRemainingDistance(
    List<LatLng> route,
    LatLng currentLocation,
  ) {
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
      final distance = _distanceToLineSegmentSimple(
        point,
        segmentStart,
        segmentEnd,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance; // * Returns in meters
  }

  /// * Calculate distance to line segment (simplified version - uses closest endpoint)
  double _distanceToLineSegmentSimple(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
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
        math.cos(_toRadians(point1.latitude)) *
            math.cos(_toRadians(point2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

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

    return {"along": bestAlong, "distance": bestDistance};
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
      final minDistance = math.max(
        minMeters,
        width * metersPerPixel * 1.2,
      ); // * At least 1.2x marker width

      // * Check if this marker is too close to any already-filtered marker.
      final tooClose = filtered.any((existing) {
        final existingLocation = getLocation(existing);
        final distance = _calculateHaversineDistance(
          location,
          existingLocation,
        );
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
