/// * SmartRoad Map Abstraction — Marker Model
/// *
/// * Platform-agnostic marker definition.
/// * Converted to native markers by each map implementation.
import 'package:flutter/widgets.dart';
import 'map_types.dart';

/// * Marker anchor point
enum MarkerAnchor {
  center,
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// * Marker definition
class MapMarker {
  final String id;
  final MapCoord coord;
  final String? iconImageId; // reference to a registered image
  final String? label;
  final MarkerAnchor anchor;
  final double iconSize;
  final double iconOpacity;
  final double rotation;
  final bool draggable;
  final Map<String, dynamic> properties;
  final Widget? customWidget; // for complex markers (falls back to symbol layer)

  const MapMarker({
    required this.id,
    required this.coord,
    this.iconImageId,
    this.label,
    this.anchor = MarkerAnchor.center,
    this.iconSize = 1.0,
    this.iconOpacity = 1.0,
    this.rotation = 0.0,
    this.draggable = false,
    this.properties = const {},
    this.customWidget,
  });

  MapMarker copyWith({
    String? id,
    MapCoord? coord,
    String? iconImageId,
    String? label,
    MarkerAnchor? anchor,
    double? iconSize,
    double? iconOpacity,
    double? rotation,
    bool? draggable,
    Map<String, dynamic>? properties,
    Widget? customWidget,
  }) =>
      MapMarker(
        id: id ?? this.id,
        coord: coord ?? this.coord,
        iconImageId: iconImageId ?? this.iconImageId,
        label: label ?? this.label,
        anchor: anchor ?? this.anchor,
        iconSize: iconSize ?? this.iconSize,
        iconOpacity: iconOpacity ?? this.iconOpacity,
        rotation: rotation ?? this.rotation,
        draggable: draggable ?? this.draggable,
        properties: properties ?? this.properties,
        customWidget: customWidget ?? this.customWidget,
      );
}

/// * Cluster marker (aggregates multiple markers)
class ClusterMarker {
  final String id;
  final MapCoord coord;
  final int count;
  final List<MapMarker> markers;

  const ClusterMarker({
    required this.id,
    required this.coord,
    required this.count,
    required this.markers,
  });
}
