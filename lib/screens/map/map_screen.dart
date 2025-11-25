import "package:flutter/material.dart";
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
import "../../services/location_service.dart";

// * Import the notifier type
import "../../providers/hazards_provider.dart" show MapHazardsNotifier;

/// * Map screen showing hazards on OpenStreetMap
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
  final Dio _dio = Dio();
  
  @override
  void initState() {
    super.initState();
    // * Initialize map controller and location
    _mapController = MapController();
    _currentLocation = LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    _isInitialized = true;
    
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
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dio.close();
    super.dispose();
  }
  
  /// * Search for locations using Nominatim API
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
    
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'SmartRoad App',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response.data);
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
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
  
  /// * Select a search result and move map to it
  void _selectSearchResult(Map<String, dynamic> result) {
    try {
      final lat = double.parse(result['lat'].toString());
      final lon = double.parse(result['lon'].toString());
      final location = LatLng(lat, lon);
      
      // * Move map to location
      _mapController.move(location, 15.0);
      
      // * Close search results
      setState(() {
        _showSearchResults = false;
        _searchFocusNode.unfocus();
      });
      
      // * Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Navigated to: ${result['display_name'] ?? 'Location'}"),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error selecting search result: $e");
    }
  }
  
  Future<void> _loadCurrentLocation() async {
    try {
      debugPrint("📍 [MapScreen] Loading current location...");
      final locationAsync = ref.read(currentLocationProvider);
      locationAsync.whenData((position) {
        if (mounted) {
          if (position != null) {
            final location = LatLng(position.latitude, position.longitude);
            debugPrint("📍 [MapScreen] Got location: ${location.latitude}, ${location.longitude}");
            setState(() {
              _currentLocation = location;
            });
            // * Move map to current location
            try {
              _mapController.move(location, AppConstants.defaultZoom);
              debugPrint("📍 [MapScreen] Map moved to current location");
            } catch (e) {
              debugPrint("❌ [MapScreen] Error moving map: $e");
            }
          } else {
            debugPrint("📍 [MapScreen] No location available, using default (Manila)");
            // * If location is not available, use default location (already set)
            // * Just ensure map is centered
            try {
              _mapController.move(_currentLocation, AppConstants.defaultZoom);
            } catch (e) {
              debugPrint("❌ [MapScreen] Error moving map to default: $e");
            }
          }
        }
      });
      
      // * Check for errors
      locationAsync.when(
        data: (_) {}, // Already handled above
        loading: () => debugPrint("📍 [MapScreen] Loading location..."),
        error: (error, stackTrace) {
          debugPrint("❌ [MapScreen] Error getting location: $error");
          debugPrint("❌ [MapScreen] Stack: $stackTrace");
        },
      );
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
                content: const Text("Location permission is required to show your current location"),
                backgroundColor: AppTheme.errorColor,
                action: SnackBarAction(
                  label: "OK",
                  textColor: Colors.white,
                  onPressed: () {},
                ),
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
              content: const Text("Could not get your location. Please check your browser settings."),
              backgroundColor: AppTheme.warningColor,
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
            content: Text("Error: $e"),
            backgroundColor: AppTheme.errorColor,
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
      
      // * Safely get location - ensure it's never null
      AsyncValue<Position?> locationAsync;
      try {
        debugPrint("🗺️ [MapScreen] Watching currentLocationProvider...");
        locationAsync = ref.watch(currentLocationProvider);
        debugPrint("🗺️ [MapScreen] Location provider state: ${locationAsync.valueOrNull != null ? 'has value' : 'no value'}");
      } catch (e, stackTrace) {
        debugPrint("❌ [MapScreen] Error reading location provider: $e");
        debugPrint("❌ [MapScreen] Stack: $stackTrace");
        locationAsync = const AsyncValue.loading();
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
      
      // * Update current location if we got actual user location
      locationAsync.whenData((position) {
        if (position != null && mounted) {
          final newLocation = LatLng(position.latitude, position.longitude);
          // * Only update if location actually changed (more than 100m difference)
          final distance = Geolocator.distanceBetween(
            _currentLocation.latitude,
            _currentLocation.longitude,
            newLocation.latitude,
            newLocation.longitude,
          );
          if (distance > 100) {
            debugPrint("📍 [MapScreen] Updating location to: ${newLocation.latitude}, ${newLocation.longitude}");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentLocation = newLocation;
                });
                // * Smoothly move map to new location
                _mapController.move(newLocation, AppConstants.defaultZoom);
              }
            });
          }
        }
      });
      
      // * Get current location for marker (only show if we got actual user location)
      final currentLocationForMarker = locationAsync.valueOrNull != null
          ? _currentLocation
          : null;
      
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
              ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.smartroad.app",
                maxZoom: 19,
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
                          Icons.my_location,
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
                    icon: Icons.my_location,
                    onPressed: locationAsync.valueOrNull != null
                        ? () {
                            // * Center on current location
                            _mapController.move(_currentLocation, AppConstants.defaultZoom);
                          }
                        : _requestLocationPermission,
                    tooltip: locationAsync.valueOrNull != null
                        ? "Center on my location"
                        : "Get my location",
                    backgroundColor: locationAsync.valueOrNull != null
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
                            Container(
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
                            IconButton(
                              icon: Icon(
                                Icons.filter_list,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () {
                                // * TODO: Add filter functionality
                              },
                              tooltip: "Filter hazards",
                            ),
                          ],
                        ),
                        border: InputBorder.none,
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
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: AppTheme.borderColor,
                          ),
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              leading: Icon(
                                Icons.location_on,
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
                              onTap: () => _selectSearchResult(result),
                              dense: true,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
}

