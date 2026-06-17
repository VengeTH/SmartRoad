/// * SmartRoad MapLibre Map Screen
///
/// * Minimal operational MapLibre map with search, zoom controls, and location.
/// * Feature modules (weather, hazards, routes) are wired through controllers.
import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:maplibre_gl/maplibre_gl.dart" as ml;
import "package:latlong2/latlong.dart";
import "package:geolocator/geolocator.dart";

import "../../core/map/map_config.dart";
import "../../core/map/map_types.dart";
import "../../core/theme/app_theme.dart";
import "../../models/recent_location.dart";
import "../../services/location_search_service.dart";
import "../../services/app_preferences_service.dart";
import "maplibre_map_controller.dart";
import "maplibre_layer_controller.dart";

/// * MapLibre Map Screen
class MapLibreMapScreen extends ConsumerStatefulWidget {
  const MapLibreMapScreen({super.key});

  @override
  ConsumerState<MapLibreMapScreen> createState() => _MapLibreMapScreenState();
}

class _MapLibreMapScreenState extends ConsumerState<MapLibreMapScreen> {
  // ── Core ────────────────────────────────────────────────────
  final SmartRoadMapController _mapCtrl = SmartRoadMapController();
  final MapLibreLayerController _layerCtrl = MapLibreLayerController();
  final LocationSearchService _searchService = LocationSearchService();
  final AppPreferencesService _prefsService = AppPreferencesService();

  // ── Location ────────────────────────────────────────────────
  LatLng _currentLocation = LatLng(
    MapConfig.defaultLatitude,
    MapConfig.defaultLongitude,
  );
  bool _hasPreciseLocation = false;

  // ── Search ──────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  List<RecentLocation> _recentLocations = [];
  bool _isLoadingRecents = false;

  // ── UI State ────────────────────────────────────────────────
  bool _isMapReady = false;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRecentLocations();
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ── Location (continuous stream) ──────────────────────────

  void _startLocationTracking() {
    // Quick one-shot to get the first fix fast.
    _loadCurrentLocation();
    // Then subscribe to continuous updates.
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // only update when moving ≥5 m
      ),
    ).listen((pos) {
      if (!mounted) return;
      _onLocationUpdate(pos.latitude, pos.longitude);
    }, onError: (e) {
      debugPrint('⚠️ [MapLibreMapScreen] Location stream error: $e');
    });
  }

  void _onLocationUpdate(double lat, double lng) {
    final loc = LatLng(lat, lng);
    setState(() {
      _currentLocation = loc;
      _hasPreciseLocation = true;
    });
    if (_isMapReady) {
      _mapCtrl.updateUserLocationMarker(ml.LatLng(lat, lng));
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      _onLocationUpdate(pos.latitude, pos.longitude);
    } catch (_) {
      debugPrint('⚠️ [MapLibreMapScreen] Could not get location');
    }
  }

  void _centerOnLocation() {
    if (!_isMapReady) return;
    _mapCtrl.animateTo(
      center: MapCoord(
        _currentLocation.latitude,
        _currentLocation.longitude,
      ),
      zoom: MapConfig.defaultZoom,
    );
  }

  // ── Map Ready ───────────────────────────────────────────────

  void _onMapCreated(ml.MaplibreMapController controller) {
    _mapCtrl.onMapReady(controller);
    _layerCtrl.bind(controller);
    setState(() => _isMapReady = true);
    debugPrint('🗺️ [MapLibreMapScreen] Map ready');
  }

  // ── Search ──────────────────────────────────────────────────

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await _searchService.searchLocation(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _showSearchResults = true;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onResultTapped(LocationSearchResult result) {
    _mapCtrl.animateTo(
      center: MapCoord(result.latitude, result.longitude),
      zoom: 15,
    );

    setState(() {
      _showSearchResults = false;
      _searchCtrl.clear();
    });

    _prefsService.addRecentLocation(
      label: result.displayName,
      latitude: result.latitude,
      longitude: result.longitude,
      kind: RecentLocationKind.search,
    );
  }

  Future<void> _loadRecentLocations() async {
    setState(() => _isLoadingRecents = true);
    try {
      final recents = await _prefsService.loadRecentLocations();
      if (mounted) setState(() => _recentLocations = recents);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingRecents = false);
    }
  }

  // ── Zoom ────────────────────────────────────────────────────

  void _zoomIn() {
    _mapCtrl.animateTo(
      center: MapCoord(
        _currentLocation.latitude,
        _currentLocation.longitude,
      ),
      zoom: (_mapCtrl.currentCameraPosition?.zoom ?? MapConfig.defaultZoom)
          .clamp(MapConfig.minZoom, MapConfig.maxZoom),
    );
  }

  void _zoomOut() {
    _mapCtrl.animateTo(
      center: MapCoord(
        _currentLocation.latitude,
        _currentLocation.longitude,
      ),
      zoom: (_mapCtrl.currentCameraPosition?.zoom ?? MapConfig.defaultZoom)
          .clamp(MapConfig.minZoom, MapConfig.maxZoom),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── MapLibre Map ─────────────────────────────────
          ml.MaplibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: () {
              _mapCtrl.registerMissingSpriteFallbacks();
              // Place a marker at the current (possibly default) location.
              _mapCtrl.showUserLocationMarker(
                ml.LatLng(_currentLocation.latitude, _currentLocation.longitude),
              );
            },
            onUserLocationUpdated: (location) {
              if (!mounted) return;
              final pos = location.position;
              final loc = LatLng(pos.latitude, pos.longitude);
              setState(() => _currentLocation = loc);
              _mapCtrl.updateUserLocationMarker(pos);
            },
            onMapClick: (point, latlng) {
              if (mounted) {
                setState(() {
                  _showSearchResults = false;
                  _searchFocus.unfocus();
                });
              }
            },
            onMapLongClick: (point, latlng) {
              // Future: handle right-click / long press for pins
            },
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(
                MapConfig.defaultLatitude,
                MapConfig.defaultLongitude,
              ),
              zoom: MapConfig.defaultZoom,
            ),
            styleString: MapConfig.mapLibreStyleUrl,
            compassEnabled: true,
            trackCameraPosition: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            myLocationEnabled: true,
            myLocationTrackingMode: ml.MyLocationTrackingMode.None,
            myLocationRenderMode: ml.MyLocationRenderMode.GPS,
            minMaxZoomPreference: ml.MinMaxZoomPreference(
              MapConfig.minZoom,
              MapConfig.maxZoom,
            ),
          ),

          // ── Search Bar ───────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),

          // ── Search Results ────────────────────────────────
          if (_showSearchResults)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 16,
              right: 16,
              bottom: 0,
              child: _buildSearchResults(),
            ),

          // ── Zoom Controls ─────────────────────────────────
          Positioned(
            right: 16,
            bottom: 120,
            child: _buildZoomControls(),
          ),
        ],
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.surfaceColor,
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: "Search places, roads...",
          prefixIcon:
              const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _showSearchResults = false);
                      },
                    )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (v) => _search(v),
      ),
    );
  }

  Widget _buildSearchResults() {
    final hasResults = _searchResults.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasResults ? "Search Results" : "Recent Locations",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _showSearchResults = false),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
          Expanded(
            child: hasResults
                ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final r = _searchResults[i];
                      return ListTile(
                        leading: const Icon(Icons.place,
                            color: AppTheme.primaryColor),
                        title: Text(
                          r.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _onResultTapped(r),
                      );
                    },
                  )
                : _isLoadingRecents
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _recentLocations.length,
                        itemBuilder: (ctx, i) {
                          final r = _recentLocations[i];
                          return ListTile(
                            leading: const Icon(Icons.history,
                                color: AppTheme.textSecondary),
                            title: Text(r.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _mapCtrl.animateTo(
                                  center: MapCoord(r.latitude, r.longitude),
                                  zoom: 15,
                                ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ctrlBtn(Icons.add, "Zoom In", () {
          final z = _mapCtrl.currentCameraPosition?.zoom ??
              MapConfig.defaultZoom;
          _mapCtrl.animateTo(
            center: MapCoord(
                _currentLocation.latitude, _currentLocation.longitude),
            zoom: (z + 1).clamp(MapConfig.minZoom, MapConfig.maxZoom),
          );
        }),
        const SizedBox(height: 8),
        _ctrlBtn(Icons.remove, "Zoom Out", () {
          final z = _mapCtrl.currentCameraPosition?.zoom ??
              MapConfig.defaultZoom;
          _mapCtrl.animateTo(
            center: MapCoord(
                _currentLocation.latitude, _currentLocation.longitude),
            zoom: (z - 1).clamp(MapConfig.minZoom, MapConfig.maxZoom),
          );
        }),
        const SizedBox(height: 8),
        _ctrlBtn(Icons.my_location, "My Location", _centerOnLocation,
            active: _hasPreciseLocation),
      ],
    );
  }

  Widget _ctrlBtn(IconData icon, String tooltip, VoidCallback onTap,
      {bool active = false}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon,
            color: active ? Colors.white : AppTheme.textPrimary, size: 22),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }
}
