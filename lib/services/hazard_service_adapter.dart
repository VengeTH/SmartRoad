import "dart:async";
import "../core/config/app_config.dart";
import "../models/hazard_model.dart";
import "hazard_service.dart";
import "local_hazard_service.dart";

/// * Hazard service adapter - switches between local and Supabase
class HazardServiceAdapter {
  HazardServiceAdapter._();

  static final HazardServiceAdapter instance = HazardServiceAdapter._();

  /// * Create a new hazard
  Future<HazardModel> createHazard({
    required String userId,
    required String type,
    required String description,
    required String severity,
    required double lat,
    required double lng,
    String? imageUrl,
  }) async {
    if (AppConfig.useLocalStorage) {
      return await LocalHazardService.instance.createHazard(
        userId: userId,
        type: type,
        description: description,
        severity: severity,
        lat: lat,
        lng: lng,
        imageUrl: imageUrl,
      );
    } else {
      return await HazardService.instance.createHazard(
        userId: userId,
        type: type,
        description: description,
        severity: severity,
        lat: lat,
        lng: lng,
        imageUrl: imageUrl,
      );
    }
  }

  /// * Get all active hazards
  Future<List<HazardModel>> getActiveHazards() async {
    if (AppConfig.useLocalStorage) {
      return await LocalHazardService.instance.getActiveHazards();
    } else {
      return await HazardService.instance.getActiveHazards();
    }
  }

  /// * Get hazards by user ID
  Future<List<HazardModel>> getHazardsByUserId(String userId) async {
    if (AppConfig.useLocalStorage) {
      return await LocalHazardService.instance.getHazardsByUserId(userId);
    } else {
      return await HazardService.instance.getHazardsByUserId(userId);
    }
  }

  /// * Get hazard by ID
  Future<HazardModel> getHazardById(String hazardId) async {
    if (AppConfig.useLocalStorage) {
      return await LocalHazardService.instance.getHazardById(hazardId);
    } else {
      return await HazardService.instance.getHazardById(hazardId);
    }
  }

  /// * Subscribe to realtime updates
  dynamic subscribeToHazards({
    required Function(HazardModel) onInsert,
    required Function(HazardModel) onUpdate,
    required Function(String) onDelete,
  }) {
    if (AppConfig.useLocalStorage) {
      // * For local storage, use stream subscription
      final Stream<HazardModel> stream =
          LocalHazardService.instance.subscribeToHazards();
      return stream.listen((hazard) {
        onInsert(hazard);
      });
    } else {
      return HazardService.instance.subscribeToHazards(
        onInsert: onInsert,
        onUpdate: onUpdate,
        onDelete: onDelete,
      );
    }
  }
}

