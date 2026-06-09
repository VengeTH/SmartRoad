/// * Routing Service
/// * Integrates with the SmartRoad Backend API for route calculation.
/// * Flutter → SmartRoad API → GraphHopper (never Flutter→GraphHopper directly).
import "dart:math" as math;
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "dart:convert";
import "package:latlong2/latlong.dart";
import "package:flutter/foundation.dart";
import "../core/config/env.dart";
import "../utils/polyline_smoothing.dart";

/// * Vehicle type enum
enum VehicleType {
  bigBike("Big Bike (400cc+)"),
  motorcycle("Motorcycle (≤399cc)"),
  car("Car (Private)"),
  truck("Truck"),
  pedestrian("Pedestrian"),
  deliveryRider("Delivery Rider"),
  floodSafe("Flood Safe (No Flood Areas)"),
  weatherSafe("Weather Safe (Avoid Storms)"),
  hoaAccess("HOA Access (Sticker Required)");

  final String value;
  const VehicleType(this.value);

  /// * Get GraphHopper vehicle parameter
  String get graphhopperParam {
    switch (this) {
      case VehicleType.bigBike:
      case VehicleType.motorcycle:
      case VehicleType.deliveryRider:
        return "motorcycle";
      case VehicleType.car:
      case VehicleType.floodSafe:
      case VehicleType.weatherSafe:
      case VehicleType.hoaAccess:
        return "car";
      case VehicleType.truck:
        return "truck";
      case VehicleType.pedestrian:
        return "foot";
    }
  }

  /// * Backend API profile name
  String get backendProfile {
    switch (this) {
      case VehicleType.bigBike:
        return "big_bike";
      case VehicleType.motorcycle:
        return "motorcycle";
      case VehicleType.car:
        return "car";
      case VehicleType.truck:
        return "truck";
      case VehicleType.pedestrian:
        return "pedestrian";
      case VehicleType.deliveryRider:
        return "delivery_rider";
      case VehicleType.floodSafe:
        return "flood_safe";
      case VehicleType.weatherSafe:
        return "weather_safe";
      case VehicleType.hoaAccess:
        return "hoa_access";
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.bigBike:
        return Icons.motorcycle;
      case VehicleType.motorcycle:
        return Icons.two_wheeler;
      case VehicleType.car:
        return Icons.directions_car;
      case VehicleType.truck:
        return Icons.local_shipping;
      case VehicleType.pedestrian:
        return Icons.directions_walk;
      case VehicleType.deliveryRider:
        return Icons.inventory_2_outlined;
      case VehicleType.floodSafe:
        return Icons.water_drop_outlined;
      case VehicleType.weatherSafe:
        return Icons.thunderstorm_outlined;
      case VehicleType.hoaAccess:
        return Icons.home_work_outlined;
    }
  }

  String get description {
    switch (this) {
      case VehicleType.bigBike:
        return "400cc+ motorcycles, highway capable";
      case VehicleType.motorcycle:
        return "≤399cc, alley-friendly";
      case VehicleType.car:
        return "Private vehicles, standard roads";
      case VehicleType.truck:
        return "Large vehicles, wide roads only";
      case VehicleType.pedestrian:
        return "Walking paths and sidewalks";
      case VehicleType.deliveryRider:
        return "Shortcuts + delivery entrances prioritized";
      case VehicleType.floodSafe:
        return "Avoids historically flood-prone roads";
      case VehicleType.weatherSafe:
        return "Avoids storm/typhoon-affected zones";
      case VehicleType.hoaAccess:
        return "Uses sticker-granted village roads";
    }
  }
}

/// * Route metadata for blocked shortcuts
class RouteMetadata {
  final bool blockedShortcut;
  final String? hoaName;
  final int? timeSavedMinutes;

  RouteMetadata({
    this.blockedShortcut = false,
    this.hoaName,
    this.timeSavedMinutes,
  });
}

/// * Route data model
class RouteData {
  final List<LatLng> points;
  final double distance; // * in kilometers
  final Duration duration;
  final String? instructions;
  final RouteMetadata? metadata;
  final bool isFallback;

  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    this.instructions,
    this.metadata,
    this.isFallback = false,
  });
}

/// * Routing service — calls the SmartRoad Backend API.
/// * The backend API calls GraphHopper internally.
/// * Flutter never calls GraphHopper directly.
class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  DateTime? _apiDisabledUntil;

  /// * Get the backend API base URL
  String get _apiUrl => Env.apiBaseUrl;

  /// * Calculate route via SmartRoad Backend API.
  /// *
  /// * [userStickerIds] - HOA IDs user has active stickers for
  /// * [restrictedHoaIds] - HOA IDs with restricted roads on route
  /// * [waypoints] - Optional intermediate waypoints
  Future<RouteData> calculateRoute({
    required LatLng start,
    required LatLng end,
    required VehicleType vehicle,
    bool avoidTolls = true,
    List<String> userStickerIds = const [],
    List<String> restrictedHoaIds = const [],
    List<LatLng> waypoints = const [],
  }) async {
    try {
      // * Backoff if API was recently unreachable
      final disabledUntil = _apiDisabledUntil;
      if (disabledUntil != null && DateTime.now().isBefore(disabledUntil)) {
        return _createFallbackRoute(start, end, vehicle, waypoints: waypoints);
      }

      // * Call SmartRoad Backend API
      final url = Uri.parse("$_apiUrl/api/routing/route");

      final body = {
        "start": {"lat": start.latitude, "lon": start.longitude},
        "end": {"lat": end.latitude, "lon": end.longitude},
        "vehicle": vehicle.backendProfile,
        "avoid_tolls": avoidTolls,
        if (waypoints.isNotEmpty)
          "waypoints":
              waypoints
                  .map((wp) => {"lat": wp.latitude, "lon": wp.longitude})
                  .toList(),
        if (userStickerIds.isNotEmpty) "user_sticker_ids": userStickerIds,
        if (restrictedHoaIds.isNotEmpty) "restricted_hoa_ids": restrictedHoaIds,
      };

      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "User-Agent": "SmartRoad-App/1.0",
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseApiResponse(data, vehicle);
      } else {
        // * Parse error from API
        final errorData = json.decode(response.body);
        final message =
            errorData['error']?['message'] ??
            "API error: ${response.statusCode}";
        debugPrint("⚠️ Routing API error: $message");
        return _createFallbackRoute(start, end, vehicle, waypoints: waypoints);
      }
    } catch (e) {
      debugPrint("⚠️ Routing API unavailable ($e) — using fallback");
      _apiDisabledUntil = DateTime.now().add(const Duration(seconds: 45));
      return _createFallbackRoute(start, end, vehicle, waypoints: waypoints);
    }
  }

  /// * Parse the backend API response into RouteData.
  RouteData _parseApiResponse(Map<String, dynamic> data, VehicleType vehicle) {
    if (data['success'] != true || data['data'] == null) {
      throw Exception("Invalid API response");
    }

    final routeData = data['data'];
    final pointsList = routeData['points'] as List? ?? [];

    final points =
        pointsList.map((p) {
          if (p is List) return LatLng(p[1] as double, p[0] as double);
          return LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          );
        }).toList();

    final distanceKm = (routeData['distance_km'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds =
        (routeData['duration_seconds'] as num?)?.toInt() ?? 0;
    final instructions = routeData['instructions'] as String?;
    final isFallback = routeData['is_fallback'] == true;

    // Check HOA warnings from backend
    RouteMetadata? metadata;
    if (routeData['hoa_warning'] == true) {
      metadata = RouteMetadata(
        blockedShortcut: true,
        hoaName:
            (routeData['hoa_missing_stickers'] as List?)?.first?.toString(),
        timeSavedMinutes: null,
      );
    }

    return RouteData(
      points: points,
      distance: distanceKm,
      duration: Duration(seconds: durationSeconds),
      instructions: instructions,
      metadata: metadata,
      isFallback: isFallback,
    );
  }

  /// * Fallback route (straight line + Catmull-Rom interpolation)
  /// * Only used when the backend API is unreachable.
  RouteData _createFallbackRoute(
    LatLng start,
    LatLng end,
    VehicleType vehicle, {
    List<LatLng> waypoints = const [],
  }) {
    final allPoints = <LatLng>[start, ...waypoints, end];
    final interpolatedPoints = PolylineSmoothing.catmullRomThroughWaypoints(
      allPoints,
      targetSpacingMeters: 5.0,
      minPointsPerSegment: 8,
      maxPointsPerSegment: 120,
    );

    double totalDistance = 0.0;
    for (int i = 0; i < interpolatedPoints.length - 1; i++) {
      totalDistance += _calculateDistance(
        interpolatedPoints[i],
        interpolatedPoints[i + 1],
      );
    }

    double avgSpeed;
    switch (vehicle) {
      case VehicleType.bigBike:
        avgSpeed = 50.0;
        break;
      case VehicleType.motorcycle:
      case VehicleType.deliveryRider:
        avgSpeed = 40.0;
        break;
      case VehicleType.car:
      case VehicleType.floodSafe:
      case VehicleType.weatherSafe:
      case VehicleType.hoaAccess:
        avgSpeed = 45.0;
        break;
      case VehicleType.truck:
        avgSpeed = 35.0;
        break;
      case VehicleType.pedestrian:
        avgSpeed = 5.0;
        break;
    }

    final durationMinutes = (totalDistance / avgSpeed * 60).round();
    final duration = Duration(minutes: durationMinutes);

    return RouteData(
      points: interpolatedPoints,
      distance: totalDistance,
      duration: duration,
      instructions: "Direct route (API unavailable)",
      isFallback: true,
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(end.latitude - start.latitude);
    final double dLon = _toRadians(end.longitude - start.longitude);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(start.latitude)) *
            math.cos(_toRadians(end.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
