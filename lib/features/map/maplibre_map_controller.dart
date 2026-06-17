/// * SmartRoad MapLibre Controller
///
/// * Wraps MaplibreMapController and exposes SmartRoad-specific operations.
/// * Handles camera, location, and image management.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/map/map_types.dart';

/// * SmartRoad-specific wrapper around MaplibreMapController
class SmartRoadMapController {
  MaplibreMapController? _controller;
  final Completer<void> _readyCompleter = Completer<void>();

  /// * Call when the native map is ready
  void onMapReady(MaplibreMapController controller) {
    _controller = controller;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    debugPrint('🗺️ [SmartRoadMap] MapLibre map ready');
  }

  /// * Await this before using any methods
  Future<void> get ready => _readyCompleter.future;

  bool get isReady => _readyCompleter.isCompleted;

  Future<void> dispose() async {
    _controller = null;
  }

  // ── Camera ─────────────────────────────────────────────────

  Future<void> animateTo({
    required MapCoord center,
    double zoom = 12.0,
    double bearing = 0.0,
    double tilt = 0.0,
    double durationMs = 400,
  }) async {
    await ready;
    try {
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(center.latitude, center.longitude),
            zoom: zoom,
            bearing: bearing,
            tilt: tilt,
          ),
        ),
        duration: Duration(milliseconds: durationMs.toInt()),
      );
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] animateTo error: $e');
    }
  }

  Future<void> moveTo({required MapCoord center, double zoom = 12.0}) async {
    await ready;
    try {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(center.latitude, center.longitude),
          zoom,
        ),
        duration: Duration.zero,
      );
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] moveTo error: $e');
    }
  }

  Future<void> fitBounds(MapBounds bounds, {double padding = 50.0}) async {
    await ready;
    try {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(bounds.south, bounds.west),
            northeast: LatLng(bounds.north, bounds.east),
          ),
          left: padding,
          right: padding,
          top: padding,
          bottom: padding,
        ),
      );
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] fitBounds error: $e');
    }
  }

  // Camera position is available via the controller's cameraPosition getter
  // Requires trackCameraPosition: true on MaplibreMap widget
  MapCameraPosition? get currentCameraPosition {
    final pos = _controller?.cameraPosition;
    if (pos != null) {
      return MapCameraPosition(
        center: MapCoord(pos.target.latitude, pos.target.longitude),
        zoom: pos.zoom,
        bearing: pos.bearing,
        tilt: pos.tilt,
      );
    }
    return null;
  }

  // ── User Location Tracking ─────────────────────────────────

  Future<void> enableLocationTracking() async {
    await ready;
    try {
      await _controller?.updateMyLocationTrackingMode(
        MyLocationTrackingMode.Tracking,
      );
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] enableLocationTracking error: $e');
    }
  }

  Future<void> disableLocationTracking() async {
    await ready;
    try {
      await _controller?.updateMyLocationTrackingMode(
        MyLocationTrackingMode.None,
      );
    } catch (_) {}
  }

  // ── Images ──────────────────────────────────────────────────

  Future<void> addImage(String id, Uint8List bytes) async {
    await ready;
    try {
      await _controller?.addImage(id, bytes);
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] addImage error: $e');
    }
  }

  /// * Register transparent fallback images for sprite names referenced
  /// * by the OpenMapTiles / OFM Liberty style but absent from the sprite
  /// * sheet.  This silences the `styleimagemissing` warnings that flood
  /// * the console on web.
  static const Set<String> _missingSpriteNames = {
    'office',
    'atm',
    'recycling',
    'gate',
    'ferry_terminal',
    'sports_centre',
    'rowing',
    'brownfield',
    'multi',
    'swimming_pool',
    'motorcycle_parking',
    'bicycle_parking',
    'lift_gate',
    'toll_booth',
    'bollard',
    'hackerspace',
    'border_control',
  };

  /// * Minimal 1×1 transparent PNG (67 bytes).
  static final Uint8List _transparentPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89,
    0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT
    0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02, 0x00,
    0x01, 0xE5, 0x27, 0xDE, 0xFC,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
    0xAE, 0x42, 0x60, 0x82,
  ]);

  /// * Call once after the style finishes loading to register fallback
  /// * images for every sprite name that the tile data may reference
  /// * but that is missing from the sprite sheet.
  Future<void> registerMissingSpriteFallbacks() async {
    await ready;
    for (final name in _missingSpriteNames) {
      try {
        await _controller?.addImage(name, _transparentPng);
      } catch (_) {
        // Image may already exist – ignore.
      }
    }
    debugPrint(
      '🗺️ [SmartRoadMap] Registered ${_missingSpriteNames.length} sprite fallbacks',
    );
  }

  // ── User-Location Marker (low-level source + layer) ──────

  static const String _locSourceId = 'smartroad_user_location_source';
  static const String _locLayerId = 'smartroad_user_location_layer';
  static const String _locRingSourceId = 'smartroad_user_ring_source';
  static const String _locRingLayerId = 'smartroad_user_ring_layer';

  /// * Adds a visible blue-dot marker at [position] using low-level
  /// * GeoJSON source + circle layer (works reliably on web).
  Future<void> showUserLocationMarker(LatLng position) async {
    await ready;
    final ctrl = _controller;
    if (ctrl == null) return;

    try {
      // Remove previous marker layers/sources.
      await removeUserLocationMarker();

      // ── Inner dot ──────────────────────────────────────────
      await ctrl.addGeoJsonSource(_locSourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [position.longitude, position.latitude],
            },
            'properties': <String, dynamic>{},
          },
        ],
      });
      await ctrl.addCircleLayer(
        _locSourceId,
        _locLayerId,
        CircleLayerProperties(
          circleColor: '#4285F4',
          circleOpacity: 1.0,
          circleRadius: 8.0,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3.0,
          circleStrokeOpacity: 1.0,
        ),
      );

      // ── Outer accuracy ring ────────────────────────────────
      await ctrl.addGeoJsonSource(_locRingSourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [position.longitude, position.latitude],
            },
            'properties': <String, dynamic>{},
          },
        ],
      });
      await ctrl.addCircleLayer(
        _locRingSourceId,
        _locRingLayerId,
        CircleLayerProperties(
          circleColor: '#4285F4',
          circleOpacity: 0.15,
          circleRadius: 20.0,
          circleStrokeColor: '#4285F4',
          circleStrokeWidth: 1.0,
          circleStrokeOpacity: 0.3,
        ),
      );

      debugPrint('🔵 [SmartRoadMap] Location marker placed at $position');
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] showUserLocationMarker error: $e');
    }
  }

  /// * Moves the existing location marker to [position] by updating
  /// * the GeoJSON source data.
  Future<void> updateUserLocationMarker(LatLng position) async {
    await ready;
    final ctrl = _controller;
    if (ctrl == null) return;

    final point = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [position.longitude, position.latitude],
      },
      'properties': <String, dynamic>{},
    };

    try {
      await ctrl.setGeoJsonSource(_locSourceId, {
        'type': 'FeatureCollection',
        'features': [point],
      });
      await ctrl.setGeoJsonSource(_locRingSourceId, {
        'type': 'FeatureCollection',
        'features': [point],
      });
    } catch (e) {
      debugPrint('❌ [SmartRoadMap] updateUserLocationMarker error: $e');
      // Might need to re-create if the sources were removed.
      if (e.toString().contains('source') ||
          e.toString().contains('not found')) {
        await showUserLocationMarker(position);
      }
    }
  }

  /// * Removes the user-location marker layers and sources.
  Future<void> removeUserLocationMarker() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      await ctrl.removeLayer(_locRingLayerId);
    } catch (_) {}
    try {
      await ctrl.removeSource(_locRingSourceId);
    } catch (_) {}
    try {
      await ctrl.removeLayer(_locLayerId);
    } catch (_) {}
    try {
      await ctrl.removeSource(_locSourceId);
    } catch (_) {}
  }
}
