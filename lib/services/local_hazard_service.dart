import "dart:async";
import "../models/hazard_model.dart";
import "local_storage_service.dart";

/// * Local hazard service (no database required)
class LocalHazardService {
  LocalHazardService._();

  static final LocalHazardService instance = LocalHazardService._();
  static const String _hazardsFile = "hazards.json";
  final StreamController<HazardModel> _hazardStreamController =
      StreamController<HazardModel>.broadcast();

  /// * Get stream of new hazards (for realtime simulation)
  Stream<HazardModel> get hazardStream => _hazardStreamController.stream;

  /// * Create a new hazard report
  Future<HazardModel> createHazard({
    required String userId,
    required String type,
    required String description,
    required String severity,
    required double lat,
    required double lng,
    String? imageUrl,
  }) async {
    try {
      final List<Map<String, dynamic>> hazards =
          await LocalStorageService.instance.readJsonList(_hazardsFile);

      final String hazardId = DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, dynamic> hazardData = {
        "id": hazardId,
        "user_id": userId,
        "type": type,
        "description": description,
        "severity": severity,
        "lat": lat,
        "lng": lng,
        "image_url": imageUrl,
        "created_at": DateTime.now().toIso8601String(),
        "status": "active",
      };

      hazards.insert(0, hazardData);
      await LocalStorageService.instance.writeJsonList(_hazardsFile, hazards);

      final HazardModel hazard = HazardModel.fromJson(hazardData);

      // * Emit to stream (simulate realtime)
      _hazardStreamController.add(hazard);

      return hazard;
    } catch (e) {
      throw Exception("Failed to create hazard: ${e.toString()}");
    }
  }

  /// * Get all active hazards
  Future<List<HazardModel>> getActiveHazards() async {
    try {
      final List<Map<String, dynamic>> hazards =
          await LocalStorageService.instance.readJsonList(_hazardsFile);

      return hazards
          .where((h) => h["status"] == "active")
          .map((json) => HazardModel.fromJson(json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      throw Exception("Failed to fetch hazards: ${e.toString()}");
    }
  }

  /// * Get hazards by user ID
  Future<List<HazardModel>> getHazardsByUserId(String userId) async {
    try {
      final List<Map<String, dynamic>> hazards =
          await LocalStorageService.instance.readJsonList(_hazardsFile);

      return hazards
          .where((h) => h["user_id"] == userId)
          .map((json) => HazardModel.fromJson(json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      throw Exception("Failed to fetch user hazards: ${e.toString()}");
    }
  }

  /// * Get hazard by ID
  Future<HazardModel> getHazardById(String hazardId) async {
    try {
      final List<Map<String, dynamic>> hazards =
          await LocalStorageService.instance.readJsonList(_hazardsFile);

      try {
        final Map<String, dynamic> hazardData =
            hazards.firstWhere((h) => h["id"] == hazardId);
        return HazardModel.fromJson(hazardData);
      } catch (e) {
        throw Exception("Hazard not found");
      }
    } catch (e) {
      throw Exception("Failed to fetch hazard: ${e.toString()}");
    }
  }

  /// * Subscribe to realtime hazard updates (simulated with stream)
  Stream<HazardModel> subscribeToHazards() {
    return _hazardStreamController.stream;
  }

  void dispose() {
    _hazardStreamController.close();
  }
}

