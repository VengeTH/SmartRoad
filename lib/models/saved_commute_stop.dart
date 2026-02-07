import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "package:uuid/uuid.dart";

import "commute_state.dart";

/// * Saved commute stop for quick access
/// Allows users to save frequently visited destinations
class SavedCommuteStop {
  final String id;
  final String name;
  final String? customLabel;
  final StopCategory category;
  final LatLng location;
  final DateTime createdAt;
  final int useCount;
  
  SavedCommuteStop({
    String? id,
    required this.name,
    this.customLabel,
    required this.category,
    required this.location,
    DateTime? createdAt,
    this.useCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();
  
  /// Get display name (custom label or name)
  String get displayName => customLabel ?? name;
  
  /// Get icon for this stop's category
  IconData get categoryIcon => getCategoryIcon(category);
  
  /// Get color for this stop's category
  Color get categoryColor => getCategoryColor(category);
  
  /// Category icons mapping
  static IconData getCategoryIcon(StopCategory category) {
    switch (category) {
      case StopCategory.work:
        return Icons.work_rounded;
      case StopCategory.school:
        return Icons.school_rounded;
      case StopCategory.home:
        return Icons.home_rounded;
      case StopCategory.terminal:
        return Icons.directions_bus_rounded;
      case StopCategory.custom:
        return Icons.star_rounded;
    }
  }
  
  /// Category colors mapping
  static Color getCategoryColor(StopCategory category) {
    switch (category) {
      case StopCategory.work:
        return const Color(0xFF6366F1); // Indigo
      case StopCategory.school:
        return const Color(0xFF10B981); // Green
      case StopCategory.home:
        return const Color(0xFFEC4899); // Pink
      case StopCategory.terminal:
        return const Color(0xFFF59E0B); // Amber
      case StopCategory.custom:
        return const Color(0xFF8B5CF6); // Purple
    }
  }
  
  /// Category display names
  static String getCategoryName(StopCategory category) {
    switch (category) {
      case StopCategory.work:
        return "Work";
      case StopCategory.school:
        return "School";
      case StopCategory.home:
        return "Home";
      case StopCategory.terminal:
        return "Terminal";
      case StopCategory.custom:
        return "Custom";
    }
  }
  
  /// Create a copy with updated use count
  SavedCommuteStop incrementUseCount() {
    return copyWith(useCount: useCount + 1);
  }
  
  SavedCommuteStop copyWith({
    String? id,
    String? name,
    String? customLabel,
    StopCategory? category,
    LatLng? location,
    DateTime? createdAt,
    int? useCount,
    bool clearCustomLabel = false,
  }) {
    return SavedCommuteStop(
      id: id ?? this.id,
      name: name ?? this.name,
      customLabel: clearCustomLabel ? null : (customLabel ?? this.customLabel),
      category: category ?? this.category,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      useCount: useCount ?? this.useCount,
    );
  }
  
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "customLabel": customLabel,
    "category": category.index,
    "latitude": location.latitude,
    "longitude": location.longitude,
    "createdAt": createdAt.toIso8601String(),
    "useCount": useCount,
  };
  
  factory SavedCommuteStop.fromJson(Map<String, dynamic> json) {
    return SavedCommuteStop(
      id: json["id"] as String?,
      name: json["name"] as String? ?? "Unknown",
      customLabel: json["customLabel"] as String?,
      category: StopCategory.values[json["category"] as int? ?? 4],
      location: LatLng(
        (json["latitude"] as num?)?.toDouble() ?? 0.0,
        (json["longitude"] as num?)?.toDouble() ?? 0.0,
      ),
      createdAt: json["createdAt"] != null 
          ? DateTime.parse(json["createdAt"] as String) 
          : DateTime.now(),
      useCount: json["useCount"] as int? ?? 0,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedCommuteStop && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

