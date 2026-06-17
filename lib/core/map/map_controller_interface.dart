/// * SmartRoad Map Abstraction — Controller Interface
/// *
/// * Defines the contract that any map implementation must satisfy.
/// * App features code against this interface, never against a specific map SDK.
import 'dart:typed_data';
import 'map_types.dart';

/// * Callback signature for map events
typedef OnMapEvent = void Function(MapEvent event);
typedef OnMapTap = void Function(MapCoord coord);
typedef OnMapLongPress = void Function(MapCoord coord);
typedef OnMapMoved = void Function(MapCameraPosition position);

/// * Map event types
enum MapEventType {
  moved,
  idle,
  tap,
  longPress,
  doubleTap,
  rotationStarted,
  rotationEnded,
  zoomStarted,
  zoomEnded,
}

/// * Map event
class MapEvent {
  final MapEventType type;
  final MapCameraPosition? position;
  final MapCoord? tapCoord;

  const MapEvent({required this.type, this.position, this.tapCoord});
}

/// * Camera fit mode
enum CameraFitMode { bounds, padding }

/// * Camera bounds configuration
class CameraBoundsOptions {
  final MapBounds? bounds;
  final double? maxZoom;
  final double? minZoom;
  final double? padding;

  const CameraBoundsOptions({
    this.bounds,
    this.maxZoom,
    this.minZoom,
    this.padding,
  });
}

/// * Abstract map controller
/// *
/// * All map operations go through this interface.
/// * MapLibreMapController and FlutterMapController implement this.
abstract class IMapController {
  // ── Lifecycle ──────────────────────────────────────────────
  Future<void> dispose();

  // ── Camera ─────────────────────────────────────────────────
  MapCameraPosition get currentPosition;

  Future<void> moveCamera(
    MapCoord center,
    double zoom, {
    MapAnimationDuration duration = MapAnimationDuration.normal,
  });

  Future<void> rotateCamera(
    double bearing, {
    MapAnimationDuration duration = MapAnimationDuration.normal,
  });

  Future<void> animateTo(
    MapCameraPosition position, {
    MapAnimationDuration duration = MapAnimationDuration.normal,
  });

  Future<void> fitBounds(
    MapBounds bounds, {
    double padding = 50.0,
    MapAnimationDuration duration = MapAnimationDuration.normal,
  });

  // ── Bounds / Constraints ───────────────────────────────────
  void setCameraBounds(CameraBoundsOptions options);

  // ── Sources & Layers (GeoJSON-based) ────────────────────────
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geoJson);

  Future<void> removeSource(String sourceId);

  Future<void> addLayer(Map<String, dynamic> layerDefinition);

  Future<void> removeLayer(String layerId);

  Future<void> updateLayer(String layerId, Map<String, dynamic> properties);

  // ── Images / Symbols ────────────────────────────────────────
  Future<void> addImage(String imageId, Uint8List bytes);

  Future<void> removeImage(String imageId);

  // ── Query ───────────────────────────────────────────────────
  Future<List<MapFeature<MapCoord>>> queryFeatures({
    MapCoord? atPoint,
    String? layerId,
  });

  // ── Event Listeners ─────────────────────────────────────────
  void addListener(OnMapEvent listener);
  void removeListener(OnMapEvent listener);
  void setOnTapCallback(OnMapTap? callback);
  void setOnLongPressCallback(OnMapLongPress? callback);
  void setOnMapMovedCallback(OnMapMoved? callback);
}
