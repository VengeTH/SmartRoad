import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "dart:async";
import "../core/constants/app_constants.dart";
import "../core/theme/app_theme.dart";
import "../providers/hazard_provider.dart";
import "../providers/location_provider.dart";
import "../providers/auth_provider.dart";
import "../models/hazard_model.dart";
import "../widgets/hazard_marker.dart";
import "../widgets/hazard_details_sheet.dart";
import "../widgets/auth_dialog.dart";
import "../services/hazard_service_adapter.dart";
import "report_screen.dart";

/// * Map screen showing hazards and user location
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<HazardModel>? _hazardSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _hazardSubscription?.cancel();
    super.dispose();
  }

  /// * Setup realtime subscription for hazards
  void _setupRealtimeSubscription() {
    final HazardsNotifier hazardsNotifier = ref.read(hazardsProvider.notifier);

    final subscription = HazardServiceAdapter.instance.subscribeToHazards(
      onInsert: (hazard) {
        hazardsNotifier.addHazard(hazard);
      },
      onUpdate: (hazard) {
        hazardsNotifier.updateHazard(hazard);
      },
      onDelete: (hazardId) {
        hazardsNotifier.removeHazard(hazardId);
      },
    );

    // * Store subscription for cleanup (if it's a StreamSubscription)
    if (subscription is StreamSubscription) {
      _hazardSubscription = subscription as StreamSubscription<HazardModel>;
    }
  }

  /// * Show hazard details bottom sheet
  void _showHazardDetails(HazardModel hazard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HazardDetailsSheet(hazard: hazard),
    );
  }

  /// * Navigate to report screen
  void _navigateToReport() {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      showDialog(
        context: context,
        builder: (context) => const AuthDialog(),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ReportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LocationState locationState = ref.watch(locationProvider);
    final HazardsState hazardsState = ref.watch(hazardsProvider);

    // * Default location (Manila, Philippines)
    LatLng currentLocation = const LatLng(14.5995, 120.9842);

    if (locationState.position != null) {
      currentLocation = LatLng(
        locationState.position!.latitude,
        locationState.position!.longitude,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // * Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLocation,
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              onTap: (tapPosition, point) {
                // * Find hazard at tap point
                for (final hazard in hazardsState.hazards) {
                  final double distance = const Distance().as(
                    LengthUnit.Meter,
                    point,
                    LatLng(hazard.lat, hazard.lng),
                  );

                  if (distance < 50) {
                    _showHazardDetails(hazard);
                    break;
                  }
                }
              },
            ),
            children: [
              // * OpenStreetMap tiles
              // * NetworkTileProvider in flutter_map v8.2+ supports cancellable requests natively
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.smartroad.app",
                maxZoom: 19,
                // * NetworkTileProvider is the default and supports request cancellation
                // * No need for flutter_map_cancellable_tile_provider (deprecated)
              ),

              // * User location marker
              if (locationState.position != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

              // * Hazard markers
              MarkerLayer(
                markers: hazardsState.hazards.map((hazard) {
                  return Marker(
                    point: LatLng(hazard.lat, hazard.lng),
                    width: 50,
                    height: 50,
                    child: HazardMarker(
                      hazard: hazard,
                      onTap: () => _showHazardDetails(hazard),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // * Loading indicator
          if (locationState.isLoading || hazardsState.isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // * Error message
          if (locationState.error != null)
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  locationState.error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),

      // * Floating action button to report hazard
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToReport,
        icon: const Icon(Icons.report),
        label: const Text("Report Hazard"),
      ),
    );
  }
}

