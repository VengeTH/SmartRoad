import "package:supabase_flutter/supabase_flutter.dart";
import "../core/config/supabase_config.dart";
import "../core/constants/app_constants.dart";
import "../models/hazard_model.dart";

/// * Hazard service for managing hazard reports
class HazardService {
  HazardService._();

  static final HazardService instance = HazardService._();

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
      final Map<String, dynamic> hazardData = {
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

      final Map<String, dynamic> response = await SupabaseConfig.client
          .from("hazards")
          .insert(hazardData)
          .select()
          .single();

      return HazardModel.fromJson(response);
    } catch (e) {
      throw Exception("Failed to create hazard: ${e.toString()}");
    }
  }

  /// * Get all active hazards
  Future<List<HazardModel>> getActiveHazards() async {
    try {
      final List<dynamic> response = await SupabaseConfig.client
          .from("hazards")
          .select()
          .eq("status", "active")
          .order("created_at", ascending: false);

      return response
          .map((json) => HazardModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception("Failed to fetch hazards: ${e.toString()}");
    }
  }

  /// * Get hazards by user ID
  Future<List<HazardModel>> getHazardsByUserId(String userId) async {
    try {
      final List<dynamic> response = await SupabaseConfig.client
          .from("hazards")
          .select()
          .eq("user_id", userId)
          .order("created_at", ascending: false);

      return response
          .map((json) => HazardModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception("Failed to fetch user hazards: ${e.toString()}");
    }
  }

  /// * Get hazard by ID
  Future<HazardModel> getHazardById(String hazardId) async {
    try {
      final Map<String, dynamic> response = await SupabaseConfig.client
          .from("hazards")
          .select()
          .eq("id", hazardId)
          .single();

      return HazardModel.fromJson(response);
    } catch (e) {
      throw Exception("Failed to fetch hazard: ${e.toString()}");
    }
  }

  /// * Subscribe to realtime hazard updates
  RealtimeChannel subscribeToHazards({
    required Function(HazardModel) onInsert,
    required Function(HazardModel) onUpdate,
    required Function(String) onDelete,
  }) {
    final RealtimeChannel channel = SupabaseConfig.client
        .channel(AppConstants.hazardsChannel)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: "public",
          table: "hazards",
          callback: (payload) {
            final HazardModel hazard = HazardModel.fromJson(
              payload.newRecord,
            );
            onInsert(hazard);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: "public",
          table: "hazards",
          callback: (payload) {
            final HazardModel hazard = HazardModel.fromJson(
              payload.newRecord,
            );
            onUpdate(hazard);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: "public",
          table: "hazards",
          callback: (payload) {
            final String hazardId = payload.oldRecord["id"] as String;
            onDelete(hazardId);
          },
        )
        .subscribe();

    return channel;
  }
}

