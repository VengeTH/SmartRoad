/// * Hazard Feature Controller
/// *
/// * Manages hazard markers, clustering, and GeoJSON generation for MapLibre.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hazard.dart';
import '../../providers/hazards_provider.dart';

/// * GeoJSON feature for a hazard point
Map<String, dynamic> hazardToGeoJson(Hazard hazard) {
  final iconMap = {
    HazardType.flood: '🌊',
    HazardType.pothole: '🕳️',
    HazardType.accident: '💥',
    HazardType.traffic: '🚦',
    HazardType.landslide: '⛰️',
    HazardType.roadblock: '🚧',
    HazardType.fallenTree: '🌲',
    HazardType.debris: '🗑️',
    HazardType.closure: '🚫',
  };

  return {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [hazard.longitude, hazard.latitude],
    },
    'properties': {
      'id': hazard.id,
      'type': hazard.type.value,
      'type_label': hazard.type.value,
      'severity': hazard.severity.value,
      'description': hazard.description,
      'icon': iconMap[hazard.type] ?? '⚠️',
      'created_at': hazard.createdAt.toIso8601String(),
    },
  };
}

/// * Convert a list of hazards to a GeoJSON FeatureCollection
Map<String, dynamic> hazardsToGeoJson(List<Hazard> hazards) {
  return {
    'type': 'FeatureCollection',
    'features': hazards.map(hazardToGeoJson).toList(),
  };
}

/// * Hazard Feature Controller
class HazardFeatureController {
  List<Hazard> _hazards = [];
  bool _visible = true;
  VoidCallback? _onChanged;

  List<Hazard> get hazards => _hazards;
  bool get visible => _visible;

  void setOnChanged(VoidCallback callback) {
    _onChanged = callback;
  }

  /// * Load hazards from provider
  void loadFromProvider(WidgetRef ref) {
    final hazardsAsync = ref.read(hazardsProvider);
    hazardsAsync.whenData((hazards) {
      _hazards = hazards;
      _onChanged?.call();
    });
  }

  /// * Toggle hazard visibility
  void setVisible(bool visible) {
    _visible = visible;
    _onChanged?.call();
  }

  /// * Get GeoJSON for all visible hazards
  Map<String, dynamic> getGeoJson() {
    if (!_visible) {
      return {'type': 'FeatureCollection', 'features': []};
    }
    return hazardsToGeoJson(_hazards);
  }

  /// * Get hazard by ID from GeoJSON properties
  static Hazard? hazardFromGeoJson(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>?;
    if (props == null) return null;

    final coords =
        (feature['geometry'] as Map<String, dynamic>?)?['coordinates']
            as List<dynamic>?;
    if (coords == null || coords.length < 2) return null;

    return Hazard(
      id: props['id'] as String? ?? '',
      userId: props['user_id'] as String? ?? '',
      type: HazardType.fromString(props['type'] as String? ?? 'roadblock'),
      description: props['description'] as String? ?? '',
      severity: SeverityLevel.fromString(
        props['severity'] as String? ?? 'medium',
      ),
      latitude: (coords[1] as num).toDouble(),
      longitude: (coords[0] as num).toDouble(),
      imageUrl: props['image_url'] as String?,
      createdAt:
          DateTime.tryParse(props['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(props['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// * Get severity color for a hazard
  static String severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return '#E53935';
      case 'medium':
        return '#FB8C00';
      case 'low':
        return '#43A047';
      default:
        return '#FB8C00';
    }
  }

  /// * Dispose
  void dispose() {
    _onChanged = null;
  }
}
