/// * Map Filter Provider
/// * Manages filter state for hazards on the map
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/hazard.dart";

/// * Filter state model
class MapFilterState {
  final Set<HazardType> selectedTypes;
  final Set<SeverityLevel> selectedSeverities;
  final bool showExpired; // * Show hazards older than 24 hours
  final bool showTraffic; // * Show live traffic overlay
  
  MapFilterState({
    Set<HazardType>? selectedTypes,
    Set<SeverityLevel>? selectedSeverities,
    this.showExpired = true,
    this.showTraffic = false, // * Traffic off by default
  })  : selectedTypes = selectedTypes ?? Set.from(HazardType.values),
        selectedSeverities = selectedSeverities ?? Set.from(SeverityLevel.values);
  
  MapFilterState copyWith({
    Set<HazardType>? selectedTypes,
    Set<SeverityLevel>? selectedSeverities,
    bool? showExpired,
    bool? showTraffic,
  }) {
    return MapFilterState(
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedSeverities: selectedSeverities ?? this.selectedSeverities,
      showExpired: showExpired ?? this.showExpired,
      showTraffic: showTraffic ?? this.showTraffic,
    );
  }
  
  /// * Check if hazard matches current filters
  bool matches(Hazard hazard) {
    // * Check type filter
    if (!selectedTypes.contains(hazard.type)) {
      return false;
    }
    
    // * Check severity filter
    if (!selectedSeverities.contains(hazard.severity)) {
      return false;
    }
    
    // * Check expiry filter
    if (!showExpired) {
      final age = DateTime.now().difference(hazard.createdAt);
      if (age.inHours > 24) {
        return false;
      }
    }
    
    return true;
  }
  
  /// * Check if any filters are active
  bool get hasActiveFilters {
    return selectedTypes.length < HazardType.values.length ||
        selectedSeverities.length < SeverityLevel.values.length ||
        !showExpired ||
        showTraffic;
  }
}

/// * Map filter state provider
final mapFilterProvider = StateNotifierProvider<MapFilterNotifier, MapFilterState>((ref) {
  return MapFilterNotifier();
});

class MapFilterNotifier extends StateNotifier<MapFilterState> {
  MapFilterNotifier() : super(MapFilterState());
  
  void toggleType(HazardType type) {
    final newTypes = Set<HazardType>.from(state.selectedTypes);
    if (newTypes.contains(type)) {
      newTypes.remove(type);
    } else {
      newTypes.add(type);
    }
    state = state.copyWith(selectedTypes: newTypes);
  }
  
  void toggleSeverity(SeverityLevel severity) {
    final newSeverities = Set<SeverityLevel>.from(state.selectedSeverities);
    if (newSeverities.contains(severity)) {
      newSeverities.remove(severity);
    } else {
      newSeverities.add(severity);
    }
    state = state.copyWith(selectedSeverities: newSeverities);
  }
  
  void setShowExpired(bool value) {
    state = state.copyWith(showExpired: value);
  }
  
  void setShowTraffic(bool value) {
    state = state.copyWith(showTraffic: value);
  }
  
  void toggleTraffic() {
    state = state.copyWith(showTraffic: !state.showTraffic);
  }
  
  void resetFilters() {
    state = MapFilterState();
  }
}



