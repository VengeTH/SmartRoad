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
import "../../services/location_service.dart";
import "../../services/routing_service.dart";
import "../../providers/hazards_provider.dart" show MapHazardsNotifier;

/// * Navigation overlay widget
class _NavigationOverlay extends StatelessWidget {
  final String mode;
  final LatLng destination;
  final VoidCallback onStop;

  const _NavigationOverlay({
    required this.mode,
    required this.destination,
    required this.onStop,
  });

  String _getModeName(String mode) {
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

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'car':
        return Icons.directions_car;
      case 'motorcycle_sub400':
      case 'motorcycle_400plus':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      case 'public_transit':
        return Icons.directions_bus;
      case 'tricycle':
        return Icons.pedal_bike;
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
      case 'public_transit':
        return AppTheme.infoColor;
      case 'tricycle':
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
                Text(
                  "Navigating (${_getModeName(mode)})",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

  const _DirectionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
              color: AppTheme.borderColor,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
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
                          Icons.location_on,
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
  final Dio _dio = Dio();
  final RoutingService _routingService = RoutingService(baseUrl: AppConstants.routingApiUrl);
  
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
    _routingService.dispose();
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
      case 'motorcycle_400plus':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      case 'public_transit':
        return Icons.directions_bus;
      case 'tricycle':
        return Icons.pedal_bike;
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
      case 'public_transit':
        return AppTheme.infoColor;
      case 'tricycle':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }
  
  /// * Start navigation
  Future<void> _startNavigation(LatLng destination, String mode) async {
    try {
      if (mounted) {
        Navigator.of(context).pop(); // * Close location options sheet
        
        setState(() {
          _isNavigating = true;
          _navigationDestination = destination;
          _navigationMode = mode;
        });
        
        // * Calculate route
        await _calculateRoute(destination, mode);
        
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
    } catch (e) {
      debugPrint("❌ [MapScreen] Error starting navigation: $e");
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
  
  
  /// * Calculate route using OSRM API with PH-specific routing logic
  Future<void> _calculateRoute(LatLng destination, String mode) async {
    try {
      final origin = _currentLocation;
      
      // * Determine routing profile and constraints based on mode
      String profile;
      bool avoidTollways = false;
      bool avoidMajorRoads = false;
      String routeNote = '';
      
      switch (mode) {
        case 'car':
          profile = 'driving';
          avoidTollways = false;
          routeNote = 'Car route (Expressways allowed)';
          // * TODO: Add number coding check
          break;
          
        case 'motorcycle_sub400':
          profile = 'driving';
          avoidTollways = true; // * BANNED from expressways (NLEX, SLEX, CAVITEX, TPLEX, etc.)
          routeNote = 'Motorcycle Sub-400cc (No expressways - NLEX, SLEX, CAVITEX, TPLEX banned)';
          break;
          
        case 'motorcycle_400plus':
          profile = 'driving';
          avoidTollways = false; // * Allowed on expressways
          routeNote = 'Motorcycle 400cc+ (Expressways allowed)';
          break;
          
        case 'truck':
          profile = 'driving';
          avoidTollways = false;
          // * Check truck ban hours
          if (_isTruckBanHours()) {
            avoidMajorRoads = true; // * Avoid EDSA and major roads during ban hours
            routeNote = 'Truck route (Truck ban hours active - avoiding major roads)';
          } else {
            routeNote = 'Truck route (Normal hours)';
          }
          // * TODO: Add truck size constraints (6-wheeler, 10-wheeler)
          // * TODO: Add total truck ban areas (Manila, Makati zones)
          break;
          
        case 'public_transit':
          profile = 'driving'; // * Placeholder - would need fixed route database
          avoidTollways = false;
          routeNote = 'Public Transit (Jeepney/Bus routes - fixed franchises)';
          // * TODO: Implement fixed route matching for jeepneys/buses
          // * TODO: Add MRT/LRT/PNR integration
          break;
          
        case 'tricycle':
          profile = 'driving';
          avoidTollways = true; // * Banned from national highways
          avoidMajorRoads = true; // * Must use barangay roads only
          routeNote = 'Tricycle route (No national highways - barangay roads only)';
          break;
          
        default:
          profile = 'driving';
          avoidTollways = false;
      }
      
      // * Use GraphHopper API for better toll avoidance support
      // * GraphHopper has better support for avoiding tolls than OSRM public API
      String url;
      bool useGraphHopper = avoidTollways || avoidMajorRoads;
      
      if (useGraphHopper) {
        // * GraphHopper API with toll avoidance
        final avoidParams = <String>[];
        if (avoidTollways) {
          avoidParams.add('toll');
        }
        if (avoidMajorRoads) {
          avoidParams.add('motorway');
        }
        
        url = 'https://graphhopper.com/api/1/route'
            '?point=${origin.latitude},${origin.longitude}'
            '&point=${destination.latitude},${destination.longitude}'
            '&vehicle=$profile'
            '${avoidParams.isNotEmpty ? '&avoid=${avoidParams.join(",")}' : ''}'
            '&type=json'
            '&instructions=false'
            '&calc_points=true'
            '&key=demo'; // * Free demo key - replace with your own in production
      } else {
        // * Use OSRM for standard routes (faster, no API key needed)
        url = 'https://router.project-osrm.org/route/v1/$profile/'
            '${origin.longitude},${origin.latitude};'
            '${destination.longitude},${destination.latitude}'
            '?overview=full&geometries=geojson&alternatives=false';
      }
      
      debugPrint("📍 [MapScreen] Calculating route: $routeNote");
      if (avoidTollways) {
        debugPrint("⚠️ [MapScreen] Avoiding expressways/tollways");
      }
      if (avoidMajorRoads) {
        debugPrint("⚠️ [MapScreen] Avoiding major roads (truck ban/tricycle restrictions)");
      }
      
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        Map<String, dynamic>? selectedRoute;
        List<LatLng> routePoints = [];
        double distance = 0.0;
        double duration = 0.0;
        
        if (useGraphHopper) {
          // * Parse GraphHopper response
          final paths = response.data['paths'];
          if (paths != null && paths is List && paths.isNotEmpty) {
            selectedRoute = paths[0] as Map<String, dynamic>;
            final pointsData = selectedRoute['points'];
            if (pointsData != null && pointsData is Map) {
              final points = pointsData['coordinates'] as List?;
              if (points != null) {
                // * GraphHopper returns coordinates as [lng, lat]
                routePoints = points.map((coord) {
                  return LatLng(coord[1] as double, coord[0] as double);
                }).toList();
              }
            }
            
            final dist = selectedRoute['distance'];
            final time = selectedRoute['time'];
            if (dist != null) {
              distance = (dist as num).toDouble() / 1000; // * Convert to km
            }
            if (time != null) {
              duration = (time as num).toDouble() / 1000 / 60; // * Convert to minutes
            }
            
            if (routePoints.isEmpty) {
              throw Exception("No route points found from GraphHopper");
            }
          } else {
            throw Exception("No route found from GraphHopper");
          }
        } else {
          // * Parse OSRM response
          final code = response.data['code'];
          if (code == 'Ok') {
            final routes = response.data['routes'] as List?;
            if (routes != null && routes.isNotEmpty) {
              selectedRoute = routes[0] as Map<String, dynamic>;
              final geometry = selectedRoute['geometry'] as Map<String, dynamic>?;
              if (geometry != null) {
                final coords = geometry['coordinates'] as List?;
                if (coords != null) {
                  // * OSRM returns coordinates as [lng, lat]
                  routePoints = coords.map((coord) {
                    return LatLng(coord[1] as double, coord[0] as double);
                  }).toList();
                }
              }
              
              final dist = selectedRoute['distance'];
              final dur = selectedRoute['duration'];
              if (dist != null) {
                distance = (dist as num).toDouble() / 1000; // * Convert to km
              }
              if (dur != null) {
                duration = (dur as num).toDouble() / 60; // * Convert to minutes
              }
            } else {
              throw Exception("OSRM returned no routes");
            }
          } else {
            throw Exception("OSRM route calculation failed: $code");
          }
        }
        
        // * Additional verification: check if route still contains expressways
        if (avoidTollways && routePoints.isNotEmpty) {
          bool stillHasExpressway = _routeContainsExpressway(
            routePoints.map((p) => [p.longitude, p.latitude]).toList()
          );
          
          if (stillHasExpressway) {
            debugPrint("⚠️ [MapScreen] Route still contains expressway segments after filtering");
            // * Try to get alternative route using OSRM with alternatives
            try {
              final altUrl = 'https://router.project-osrm.org/route/v1/$profile/'
                  '${origin.longitude},${origin.latitude};'
                  '${destination.longitude},${destination.latitude}'
                  '?overview=full&geometries=geojson&alternatives=true';
              
              final altResponse = await _dio.get(altUrl);
              if (altResponse.statusCode == 200 && altResponse.data['code'] == 'Ok') {
                List<dynamic> altRoutes = altResponse.data['routes'] as List;
                
                // * Find route without expressways
                for (var route in altRoutes) {
                  final geometry = route['geometry']['coordinates'] as List;
                  bool hasExpressway = _routeContainsExpressway(geometry);
                  if (!hasExpressway) {
                    routePoints = geometry.map((coord) {
                      return LatLng(coord[1] as double, coord[0] as double);
                    }).toList();
                    distance = route['distance'] / 1000;
                    duration = route['duration'] / 60;
                    debugPrint("✅ [MapScreen] Found alternative route without expressways");
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint("⚠️ [MapScreen] Could not get alternative route: $e");
            }
          }
        }
        
        // * TODO: Filter major roads for truck ban hours and tricycle restrictions
        // * - EDSA
        // * - National Highways
        // * - Major Avenues
        
        setState(() {
          _navigationRoute = routePoints;
        });
        
        debugPrint("📍 [MapScreen] Route calculated: ${routePoints.length} points, ${distance.toStringAsFixed(2)} km, ${duration.toStringAsFixed(1)} min");
        
        if (avoidTollways || avoidMajorRoads) {
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
                        Icons.info_outline,
                        color: AppTheme.warningColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              routeNote,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text(
                              "Note: Expressway/major road filtering requires PH road database. "
                              "Route may include restricted roads.",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        throw Exception("Failed to calculate route: ${response.data['code']}");
      }
    } catch (e) {
      debugPrint("❌ [MapScreen] Error calculating route: $e");
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
                      "Could not calculate route: ${e.toString()}",
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
  
  /// * Stop navigation
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _navigationDestination = null;
      _navigationMode = null;
      _navigationRoute = null;
    });
    
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
                      "Choose your vehicle type:",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    // * Car mode
                    _DirectionOption(
                      icon: Icons.directions_car,
                      title: "Car",
                      subtitle: "Standard car navigation (Expressways allowed)",
                      onTap: () => _startNavigation(destination, 'car'),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // * Motorcycle Sub-400cc (most common)
                    _DirectionOption(
                      icon: Icons.two_wheeler,
                      title: "Motorcycle (Sub-400cc)",
                      subtitle: "No expressways - for scooters & underbones",
                      onTap: () => _startNavigation(destination, 'motorcycle_sub400'),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // * Motorcycle 400cc+
                    _DirectionOption(
                      icon: Icons.two_wheeler,
                      title: "Motorcycle (400cc+)",
                      subtitle: "Expressways allowed - for big bikes",
                      onTap: () => _startNavigation(destination, 'motorcycle_400plus'),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // * Truck mode
                    _DirectionOption(
                      icon: Icons.local_shipping,
                      title: "Truck",
                      subtitle: "Truck ban hours considered",
                      onTap: () => _startNavigation(destination, 'truck'),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // * Public Transit mode
                    _DirectionOption(
                      icon: Icons.directions_bus,
                      title: "Public Transit",
                      subtitle: "Jeepney, Bus, MRT/LRT routes",
                      onTap: () => _startNavigation(destination, 'public_transit'),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // * Tricycle mode
                    _DirectionOption(
                      icon: Icons.pedal_bike,
                      title: "Tricycle",
                      subtitle: "No national highways - barangay roads only",
                      onTap: () => _startNavigation(destination, 'tricycle'),
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
              // * Navigation route polyline
              if (_navigationRoute != null && _navigationRoute!.isNotEmpty)
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
            // * Navigation overlay (when navigating)
            if (_isNavigating && _navigationDestination != null && _navigationMode != null)
              Positioned(
                top: AppTheme.spacingMD,
                left: AppTheme.spacingMD,
                right: AppTheme.spacingMD,
                child: _NavigationOverlay(
                  mode: _navigationMode!,
                  destination: _navigationDestination!,
                  onStop: _stopNavigation,
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

