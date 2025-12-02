/// * SmartRoad MVP Routing Service
/// * Connects to backend API for route calculation
import "package:dio/dio.dart";
import "package:latlong2/latlong.dart";

/// * Route response model
class RouteResponse {
  final List<LatLng> geometry;
  final double distanceMeters;
  final int durationSeconds;
  final String profile;

  RouteResponse({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.profile,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    final geometry = (json['geometry'] as List)
        .map((coord) => LatLng(coord[0] as double, coord[1] as double))
        .toList();

    return RouteResponse(
      geometry: geometry,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      profile: json['profile'] as String,
    );
  }
}

/// * Routing service
class RoutingService {
  final Dio _dio = Dio();
  final String _baseUrl;

  RoutingService({String? baseUrl})
      : _baseUrl = baseUrl ?? "http://localhost:3000";

  /// * Calculate route
  /// * 
  /// * [origin] - Starting point
  /// * [destination] - End point
  /// * [mode] - "car" or "motorcycle"
  /// * [avoidTolls] - Whether to avoid toll roads
  /// * [userStickerIds] - List of active sticker IDs for permission-based routing
  /// * 
  /// Returns list of routes (primary + 1 alternative)
  /// 
  /// Note: The userStickerIds parameter is prepared for future implementation
  /// where GraphHopper will use sticker permissions to weight roads (e.g., 
  /// if user has Sticker A, weight Road A as 0.0 for passable routes)
  Future<List<RouteResponse>> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required String mode,
    bool avoidTolls = false,
    List<String> userStickerIds = const [],
  }) async {
    try {
      final response = await _dio.post(
        "$_baseUrl/route",
        data: {
          "origin": {
            "lat": origin.latitude,
            "lng": origin.longitude,
          },
          "destination": {
            "lat": destination.latitude,
            "lng": destination.longitude,
          },
          "mode": mode,
          "avoid_tolls": avoidTolls,
          "user_sticker_ids": userStickerIds, // * Prepared for future routing logic
        },
        options: Options(
          headers: {
            "Content-Type": "application/json",
          },
        ),
      );

      if (response.statusCode == 200) {
        final routes = (response.data['routes'] as List)
            .map((route) => RouteResponse.fromJson(route))
            .toList();
        return routes;
      } else {
        throw Exception("Route calculation failed: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error calculating route: $e");
    }
  }

  void dispose() {
    _dio.close();
  }
}




