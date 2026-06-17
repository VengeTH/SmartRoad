/// * SmartRoad Map Abstraction — Polyline Model
/// *
/// * Platform-agnostic polyline/polygon definition for routes, boundaries, etc.
import 'package:flutter/painting.dart';
import 'map_types.dart';

/// * Line cap style
enum LineCap { round, butt, square }

/// * Line join style
enum LineJoin { round, miter, bevel }

/// * Polyline definition
class MapPolyline {
  final String id;
  final List<MapCoord> points;
  final Color color;
  final double width;
  final double opacity;
  final LineCap cap;
  final LineJoin join;
  final List<double>? dashPattern;
  final bool isSelected; // highlight state
  final Map<String, dynamic> properties;

  const MapPolyline({
    required this.id,
    required this.points,
    this.color = const Color(0xFF2196F3),
    this.width = 4.0,
    this.opacity = 1.0,
    this.cap = LineCap.round,
    this.join = LineJoin.round,
    this.dashPattern,
    this.isSelected = false,
    this.properties = const {},
  });

  MapPolyline copyWith({
    String? id,
    List<MapCoord>? points,
    Color? color,
    double? width,
    double? opacity,
    LineCap? cap,
    LineJoin? join,
    List<double>? dashPattern,
    bool? isSelected,
    Map<String, dynamic>? properties,
  }) => MapPolyline(
    id: id ?? this.id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    opacity: opacity ?? this.opacity,
    cap: cap ?? this.cap,
    join: join ?? this.join,
    dashPattern: dashPattern ?? this.dashPattern,
    isSelected: isSelected ?? this.isSelected,
    properties: properties ?? this.properties,
  );
}
