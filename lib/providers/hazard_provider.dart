import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/hazard_model.dart";
import "../services/hazard_service.dart";

/// * Hazards state provider
final hazardsProvider = StateNotifierProvider<HazardsNotifier, HazardsState>(
  (ref) => HazardsNotifier(),
);

/// * Hazards state
class HazardsState {
  final List<HazardModel> hazards;
  final bool isLoading;
  final String? error;

  HazardsState({
    this.hazards = const [],
    this.isLoading = false,
    this.error,
  });

  HazardsState copyWith({
    List<HazardModel>? hazards,
    bool? isLoading,
    String? error,
  }) {
    return HazardsState(
      hazards: hazards ?? this.hazards,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// * Hazards notifier
class HazardsNotifier extends StateNotifier<HazardsState> {
  HazardsNotifier() : super(HazardsState()) {
    loadHazards();
  }

  final HazardService _hazardService = HazardService.instance;

  /// * Load all active hazards
  Future<void> loadHazards() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final List<HazardModel> hazards = await _hazardService.getActiveHazards();
      state = state.copyWith(hazards: hazards, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// * Create a new hazard
  Future<bool> createHazard({
    required String userId,
    required String type,
    required String description,
    required String severity,
    required double lat,
    required double lng,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final HazardModel hazard = await _hazardService.createHazard(
        userId: userId,
        type: type,
        description: description,
        severity: severity,
        lat: lat,
        lng: lng,
        imageUrl: imageUrl,
      );
      final List<HazardModel> updatedHazards = [hazard, ...state.hazards];
      state = state.copyWith(hazards: updatedHazards, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// * Add hazard (from realtime)
  void addHazard(HazardModel hazard) {
    if (!state.hazards.any((h) => h.id == hazard.id)) {
      final List<HazardModel> updatedHazards = [hazard, ...state.hazards];
      state = state.copyWith(hazards: updatedHazards);
    }
  }

  /// * Update hazard (from realtime)
  void updateHazard(HazardModel hazard) {
    final List<HazardModel> updatedHazards = state.hazards.map((h) {
      return h.id == hazard.id ? hazard : h;
    }).toList();
    state = state.copyWith(hazards: updatedHazards);
  }

  /// * Remove hazard (from realtime)
  void removeHazard(String hazardId) {
    final List<HazardModel> updatedHazards =
        state.hazards.where((h) => h.id != hazardId).toList();
    state = state.copyWith(hazards: updatedHazards);
  }
}

