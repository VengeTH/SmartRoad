/// * MapLibre Layer Controller
///
/// * Manages runtime annotations on the MapLibre map using annotation managers.
/// * Weather raster layers use MaplibreMapController.addSource/addLayer.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// * Weather layer types
enum MlWeatherLayerType { rain, clouds, temperature, none }

/// * Layer state tracking
class MapLibreLayerState {
  bool rainVisible = false;
  bool cloudsVisible = false;
  bool temperatureVisible = false;
  bool hazardsVisible = true;
  bool floodZonesVisible = true;
  bool hoaEntrancesVisible = true;
  bool routeVisible = true;

  void reset() {
    rainVisible = false;
    cloudsVisible = false;
    temperatureVisible = false;
    hazardsVisible = true;
    floodZonesVisible = true;
    hoaEntrancesVisible = true;
    routeVisible = true;
  }
}

/// * Controller for managing MapLibre layers and annotations
class MapLibreLayerController {
  final MapLibreLayerState state = MapLibreLayerState();
  MaplibreMapController? _controller;

  MapLibreLayerController();

  void bind(MaplibreMapController controller) => _controller = controller;
  void unbind() => _controller = null;
  bool get isBound => _controller != null;

  // ── Raster Tile Layers (Weather, Traffic) ─────────────────

  Future<void> addWeatherTileLayer({
    required String id,
    required String tileUrlTemplate,
    required double opacity,
  }) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final sourceId = 'src_$id';
    final layerId = 'lyr_$id';
    try {
      await ctrl.removeLayer(layerId);
    } catch (_) {}
    try {
      await ctrl.removeSource(sourceId);
    } catch (_) {}
    try {
      await ctrl.addSource(
        sourceId,
        RasterSourceProperties(tiles: [tileUrlTemplate], tileSize: 256),
      );
      await ctrl.addLayer(
        sourceId,
        layerId,
        RasterLayerProperties(rasterOpacity: opacity),
      );
    } catch (e) {
      debugPrint('❌ [MapLibreLayers] Failed raster $id: $e');
    }
  }

  Future<void> removeWeatherLayer(String id) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      await ctrl.removeLayer('lyr_$id');
    } catch (_) {}
    try {
      await ctrl.removeSource('src_$id');
    } catch (_) {}
  }

  // ── Route Lines ────────────────────────────────────────────

  Future<void> addRoutePolyline({
    required String routeId,
    required List<List<double>> coordinates,
    required Color color,
    double width = 5.0,
    double opacity = 1.0,
    bool isAlternative = false,
  }) async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.lineManager == null) return;
    final latLngs = coordinates.map((c) => LatLng(c[1], c[0])).toList();
    try {
      await ctrl.lineManager!.add(
        Line(
          'route_$routeId',
          LineOptions(
            geometry: latLngs,
            lineColor: color.toHex(),
            lineWidth: width,
            lineOpacity: opacity,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [MapLibreLayers] Failed route $routeId: $e');
    }
  }

  Future<void> removeAllRoutes() async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.lineManager == null) return;
    try {
      await ctrl.lineManager!.clear();
    } catch (_) {}
  }

  // ── Hazard Circles ─────────────────────────────────────────

  Future<void> addHazardMarkers({
    required String groupId,
    required List<Map<String, dynamic>> features,
  }) async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.circleManager == null) return;
    final circles = <Circle>[];
    for (final f in features) {
      final coords = f['geometry']?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;
      final lat = (coords[1] as num).toDouble();
      final lng = (coords[0] as num).toDouble();
      final severity = f['properties']?['severity'] as String? ?? 'medium';
      final c = switch (severity.toLowerCase()) {
        'high' => const Color(0xFFE53935),
        'medium' => const Color(0xFFFB8C00),
        _ => const Color(0xFF43A047),
      };
      circles.add(
        Circle(
          'hazard_${circles.length}',
          CircleOptions(
            geometry: LatLng(lat, lng),
            circleColor: c.toHex(),
            circleRadius: 8,
            circleOpacity: 0.85,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        ),
      );
    }
    if (circles.isNotEmpty) {
      try {
        await ctrl.circleManager!.addAll(circles);
      } catch (e) {
        debugPrint('❌ [MapLibreLayers] Hazards: $e');
      }
    }
  }

  Future<void> removeAllHazards() async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.circleManager == null) return;
    try {
      await ctrl.circleManager!.clear();
    } catch (_) {}
  }

  // ── HOA Entrance Circles ───────────────────────────────────

  Future<void> addHoaEntranceMarkers({
    required List<Map<String, dynamic>> features,
  }) async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.circleManager == null) return;
    final circles = <Circle>[];
    for (final f in features) {
      final coords = f['geometry']?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;
      final lat = (coords[1] as num).toDouble();
      final lng = (coords[0] as num).toDouble();
      final type = f['properties']?['entranceType'] as String? ?? 'main';
      final c = switch (type) {
        'delivery' => const Color(0xFF1B5E20),
        'main' => const Color(0xFF0D47A1),
        'visitor' => const Color(0xFFF57F17),
        'emergency' => const Color(0xFFB71C1C),
        _ => const Color(0xFF4E342E),
      };
      circles.add(
        Circle(
          'hoa_${circles.length}',
          CircleOptions(
            geometry: LatLng(lat, lng),
            circleColor: c.toHex(),
            circleRadius: 10,
            circleOpacity: 0.9,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        ),
      );
    }
    if (circles.isNotEmpty) {
      try {
        await ctrl.circleManager!.addAll(circles);
      } catch (e) {
        debugPrint('❌ [MapLibreLayers] HOA: $e');
      }
    }
  }

  Future<void> removeAllHoaEntrances() async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.circleManager == null) return;
    try {
      await ctrl.circleManager!.clear();
    } catch (_) {}
  }

  // ── Flood Zone Fills ───────────────────────────────────────

  Future<void> addFloodZonePolygon({
    required String zoneId,
    required List<List<List<double>>> coordinates,
    required String severity,
  }) async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.fillManager == null) return;
    final c = switch (severity) {
      'extreme' => const Color(0x44E53935),
      'high' => const Color(0x44FB8C00),
      'moderate' => const Color(0x44FDD835),
      _ => const Color(0x4443A047),
    };
    final outerRing =
        (coordinates.isNotEmpty ? coordinates.first : [])
            .map((c) => LatLng(c[1], c[0]))
            .toList();
    if (outerRing.length < 3) return;
    try {
      await ctrl.fillManager!.add(
        Fill(
          'flood_$zoneId',
          FillOptions(
            geometry: [outerRing],
            fillColor: c.toHex(),
            fillOpacity: 0.35,
            fillOutlineColor: '#E53935',
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [MapLibreLayers] Flood: $e');
    }
  }

  Future<void> removeAllFloodZones() async {
    final ctrl = _controller;
    if (ctrl == null || ctrl.fillManager == null) return;
    try {
      await ctrl.fillManager!.clear();
    } catch (_) {}
  }

  // ── Traffic ────────────────────────────────────────────────

  Future<void> addTrafficLayer({
    required String tileUrlTemplate,
    double opacity = 0.7,
  }) async {
    await addWeatherTileLayer(
      id: 'traffic',
      tileUrlTemplate: tileUrlTemplate,
      opacity: opacity,
    );
  }

  Future<void> removeTrafficLayer() async {
    await removeWeatherLayer('traffic');
  }

  // ── Clear All ──────────────────────────────────────────────

  Future<void> clearAll() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      ctrl.lineManager?.clear();
    } catch (_) {}
    try {
      ctrl.circleManager?.clear();
    } catch (_) {}
    try {
      ctrl.fillManager?.clear();
    } catch (_) {}
    try {
      ctrl.symbolManager?.clear();
    } catch (_) {}
    state.reset();
  }
}

/// * Color to hex string
extension ColorToHex on Color {
  String toHex() {
    final red = (r * 255).round().toRadixString(16).padLeft(2, '0');
    final green = (g * 255).round().toRadixString(16).padLeft(2, '0');
    final blue = (b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$red$green$blue';
  }
}
