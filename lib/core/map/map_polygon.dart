/// * SmartRoad Map Abstraction — Polygon Model
/// *
/// * Platform-agnostic polygon definition for flood zones, village boundaries, etc.
import 'package:flutter/painting.dart';
import 'map_types.dart';

/// * Fill pattern
enum FillPattern { solid, crossHatch, diagonal }

/// * Polygon definition
class MapPolygon {
  final String id;
  final List<List<MapCoord>> rings; // outer + optional holes
  final Color fillColor;
  final double fillOpacity;
  final Color strokeColor;
  final double strokeWidth;
  final List<double>? strokeDashPattern;
  final FillPattern fillPattern;
  final String? label;
  final Map<String, dynamic> properties;

  const MapPolygon({
    required this.id,
    required this.rings,
    this.fillColor = const Color(0x442196F3),
    this.fillOpacity = 0.3,
    this.strokeColor = const Color(0xFF2196F3),
    this.strokeWidth = 2.0,
    this.strokeDashPattern,
    this.fillPattern = FillPattern.solid,
    this.label,
    this.properties = const {},
  });

  List<MapCoord> get outerRing => rings.isNotEmpty ? rings.first : [];

  MapPolygon copyWith({
    String? id,
    List<List<MapCoord>>? rings,
    Color? fillColor,
    double? fillOpacity,
    Color? strokeColor,
    double? strokeWidth,
    List<double>? strokeDashPattern,
    FillPattern? fillPattern,
    String? label,
    Map<String, dynamic>? properties,
  }) => MapPolygon(
    id: id ?? this.id,
    rings: rings ?? this.rings,
    fillColor: fillColor ?? this.fillColor,
    fillOpacity: fillOpacity ?? this.fillOpacity,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    strokeDashPattern: strokeDashPattern ?? this.strokeDashPattern,
    fillPattern: fillPattern ?? this.fillPattern,
    label: label ?? this.label,
    properties: properties ?? this.properties,
  );
}
