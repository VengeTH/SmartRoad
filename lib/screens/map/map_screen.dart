import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../../providers/hazards_provider.dart";
import "../../providers/location_provider.dart";
import "../../models/hazard.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_theme.dart";
import "../../widgets/hazard_marker.dart";
import "../../widgets/hazard_detail_sheet.dart";
import "../report/report_hazard_screen.dart";

/// * Map screen showing hazards on OpenStreetMap
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  Hazard? _selectedHazard;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }
  
  Future<void> _loadCurrentLocation() async {
    final locationAsync = ref.read(currentLocationProvider);
    locationAsync.whenData((position) {
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        // * Move map to current location
        _mapController.move(_currentLocation!, AppConstants.defaultZoom);
      }
    });
  }
  
  void _onMapReady() {
    // * Load all hazards initially (will be optimized with PostGIS RPC later)
    // * For now, load a reasonable bounding box around current location
    final center = _currentLocation ?? 
        LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    const offset = 0.1; // * Roughly 10km
    ref.read(mapHazardsProvider.notifier).loadHazardsInBounds(
      center.latitude - offset,
      center.longitude - offset,
      center.latitude + offset,
      center.longitude + offset,
    );
  }
  
  void _onMapMoved() {
    // * Reload hazards when map moves significantly
    // * For MVP, we'll reload all hazards (can be optimized later)
    final center = _currentLocation ?? 
        LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    const offset = 0.1;
    ref.read(mapHazardsProvider.notifier).loadHazardsInBounds(
      center.latitude - offset,
      center.longitude - offset,
      center.latitude + offset,
      center.longitude + offset,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final hazards = ref.watch(mapHazardsProvider);
    final locationAsync = ref.watch(currentLocationProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? 
                  LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude),
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              onMapReady: _onMapReady,
              onMapEvent: (event) {
                if (event is MapEventMove) {
                  _onMapMoved();
                }
              },
              onTap: (tapPosition, point) {
                // * Close detail sheet if tapping map
                setState(() => _selectedHazard = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.smartroad.app",
                maxZoom: 19,
              ),
              // * Current location marker
              if (locationAsync.valueOrNull != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              // * Hazard markers
              MarkerLayer(
                markers: hazards.map((hazard) {
                  return Marker(
                    point: LatLng(hazard.latitude, hazard.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedHazard = hazard);
                      },
                      child: HazardMarker(hazard: hazard),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // * Hazard detail bottom sheet
          if (_selectedHazard != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: HazardDetailSheet(
                hazard: _selectedHazard!,
                onClose: () => setState(() => _selectedHazard = null),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ReportHazardScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_alert),
        label: const Text("Report Hazard"),
      ),
    );
  }
}

