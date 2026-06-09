/// * Routing Service
/// * Integrates with GraphHopper for route calculation
import "dart:math" as math;
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "dart:convert";
import "package:latlong2/latlong.dart";
import "package:flutter/foundation.dart";
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
  
  /// * Get GraphHopper profile name for custom profiles
  String get graphhopperProfile {
    switch (this) {
      case VehicleType.deliveryRider:
        return "delivery_rider";
      case VehicleType.floodSafe:
        return "flood_safe";
      case VehicleType.weatherSafe:
        return "weather_safe";
      case VehicleType.hoaAccess:
        return "hoa_access";
      default:
        return graphhopperParam;
    }
  }
  
  /// * Get icon for vehicle type
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
  
  /// * Get description for vehicle type
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
  final RouteMetadata? metadata; // * Permission-based routing metadata
  
  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    this.instructions,
    this.metadata,
  });
}

/// * Routing service for calculating routes
class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();
  
  // * GraphHopper API endpoint (local Docker instance)
  // * Override with: --dart-define=GRAPH_HOPPER_URL=https://your-host
  static const String _graphhopperUrl = String.fromEnvironment(
    "GRAPH_HOPPER_URL",
    defaultValue: "http://localhost:8989",
  );

  // * For Flutter Web, GraphHopper is usually unavailable (localhost:8989 not running,
  // * or blocked by CORS). Users can explicitly enable it with:
  // *   --dart-define=ENABLE_GRAPH_HOPPER_WEB=true
  static const bool _enableGraphhopperOnWeb =
      bool.fromEnvironment("ENABLE_GRAPH_HOPPER_WEB", defaultValue: false);

  DateTime? _graphhopperDisabledUntil;
  
  /// * Calculate route between two points
  /// * 
  /// * [userStickerIds] - List of HOA IDs for which user has active stickers
  /// * [restrictedHoaIds] - List of HOA IDs that have restricted roads
  /// * [waypoints] - Optional intermediate waypoints for route customization
  Future<RouteData> calculateRoute({
    required LatLng start,
    required LatLng end,
    required VehicleType vehicle,
    bool avoidTolls = true,
    List<String> userStickerIds = const [],
    List<String> restrictedHoaIds = const [],
    List<LatLng> waypoints = const [], // * Intermediate waypoints
  }) async {
    try {
      // * On Web, default to fallback routing unless explicitly enabled.
      if (kIsWeb && !_enableGraphhopperOnWeb) {
        return _createFallbackRoute(start, end, vehicle, waypoints: waypoints);
      }

      // * Backoff if GraphHopper was recently unreachable (prevents console spam).
      final disabledUntil = _graphhopperDisabledUntil;
      if (disabledUntil != null && DateTime.now().isBefore(disabledUntil)) {
        return _createFallbackRoute(start, end, vehicle, waypoints: waypoints);
      }

      // * Build GraphHopper API URL with waypoints
      final vehicleParam = vehicle.graphhopperParam;
      final points = [
        "${start.latitude},${start.longitude}",
        ...waypoints.map((wp) => "${wp.latitude},${wp.longitude}"),
        "${end.latitude},${end.longitude}",
      ];
      final pointsParam = points.map((p) => "point=$p").join("&");
      
      final url = Uri.parse(
        "$_graphhopperUrl/route"
        "?$pointsParam"
        "&vehicle=$vehicleParam"
        "&type=json"
        "&instructions=true"
        "&calc_points=true"
        "&points_encoded=false"
      );
      
      final response = await http.get(
        url,
        // ! Browsers do not allow setting User-Agent; also triggers CORS preflight.
        headers: kIsWeb
            ? null
            : {
              "User-Agent": "SmartRoad App (contact@smartroad.app)",
            },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // * Parse route data from GraphHopper response
        final paths = data['paths'] as List?;
        if (paths == null || paths.isEmpty) {
          throw Exception("No route found");
        }
        
        final path = paths[0] as Map<String, dynamic>;
        final pointsData = path['points'] as Map<String, dynamic>?;
        final coordinates = pointsData?['coordinates'] as List?;
        
        // * Parse coordinates
        List<LatLng> routePoints = [];
        if (coordinates != null) {
          for (final coord in coordinates) {
            if (coord is List && coord.length >= 2) {
              routePoints.add(LatLng(
                (coord[1] as num).toDouble(), // * lat
                (coord[0] as num).toDouble(), // * lon
              ));
            }
          }
        }
        
        // * Parse distance (in meters, convert to km)
        final distanceMeters = (path['distance'] as num?)?.toDouble() ?? 0.0;
        final distanceKm = distanceMeters / 1000.0;
        
        // * Parse duration
        // * GraphHopper typically returns time in milliseconds, but some versions/configurations
        // * may return in seconds. We'll check the value and convert appropriately.
        final timeValue = (path['time'] as num?)?.toDouble() ?? 0.0;
        
        // * Sanity check: GraphHopper time should be in milliseconds
        // * If timeValue is very large (> 1,000,000), it might be in a different unit
        // * For a 1.9km route at 50km/h, expected time is ~2.3 minutes = ~138,000 ms
        // * If we get something like 1,000,000+ ms for a short route, it's likely in seconds
        Duration duration;
        if (timeValue > 1000000) {
          // * Very large value - likely in seconds, convert to milliseconds
          duration = Duration(milliseconds: (timeValue * 1000).round());
        } else if (timeValue > 0 && timeValue < 100 && distanceKm > 0.5) {
          // * Very small value for a route > 0.5km - definitely in seconds
          // * (e.g., 2 seconds for 1.9km would be 2000ms, but if we see 2, it's seconds)
          duration = Duration(milliseconds: (timeValue * 1000).round());
        } else {
          // * Assume milliseconds (default GraphHopper behavior)
          duration = Duration(milliseconds: timeValue.round());
        }
        
        // * Parse instructions
        final instructionsData = path['instructions'] as List?;
        String? instructions;
        if (instructionsData != null && instructionsData.isNotEmpty) {
          final instructionTexts = instructionsData
              .map((i) => (i as Map)['text'] as String?)
              .where((t) => t != null)
              .toList();
          instructions = instructionTexts.join(" → ");
        }
        
        // * Permission-based routing: Check for blocked shortcuts
        RouteMetadata? metadata;
        if (restrictedHoaIds.isNotEmpty) {
          metadata = await _checkBlockedShortcuts(
            routePoints: routePoints,
            userStickerIds: userStickerIds,
            restrictedHoaIds: restrictedHoaIds,
            allowedRouteDistance: distanceKm,
            allowedRouteDuration: duration,
            start: start,
            end: end,
            vehicle: vehicle,
            avoidTolls: avoidTolls,
          );
        }
        
        return RouteData(
          points: routePoints,
          distance: distanceKm,
          duration: duration,
          instructions: instructions,
          metadata: metadata,
        );
      } else {
        throw Exception("GraphHopper API error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Routing error: $e");
      // * Prevent hammering GraphHopper if it's down (especially in Flutter Web).
      _graphhopperDisabledUntil = DateTime.now().add(const Duration(seconds: 45));
      // * Return a fallback route (straight line) if GraphHopper is unavailable
      return _createFallbackRoute(start, end, vehicle, waypoints: waypoints);
    }
  }
  
  /// * Create a fallback route with smooth interpolation through waypoints when GraphHopper is unavailable
  RouteData _createFallbackRoute(LatLng start, LatLng end, VehicleType vehicle, {List<LatLng> waypoints = const []}) {
    // * Build route: Start → WP1 → WP2 → ... → End
    // * Uses Catmull–Rom smoothing to avoid sharp corners between waypoints.
    final allPoints = <LatLng>[start, ...waypoints, end];
    final interpolatedPoints = PolylineSmoothing.catmullRomThroughWaypoints(
      allPoints,
      targetSpacingMeters: 5.0,
      minPointsPerSegment: 8,
      maxPointsPerSegment: 120,
    );

    // * Calculate distance along the generated polyline (more accurate than waypoint-to-waypoint).
    double totalDistance = 0.0;
    for (int i = 0; i < interpolatedPoints.length - 1; i++) {
      totalDistance += _calculateDistance(interpolatedPoints[i], interpolatedPoints[i + 1]);
    }

    // * Estimate duration based on vehicle type
    double avgSpeed;
    switch (vehicle) {
      case VehicleType.bigBike:
        avgSpeed = 50.0; // * km/h
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
      instructions: "Direct route (GraphHopper unavailable)",
    );
  }
  
  /// * Calculate distance between two points (Haversine formula)
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(end.latitude - start.latitude);
    final double dLon = _toRadians(end.longitude - start.longitude);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(start.latitude)) * math.cos(_toRadians(end.latitude)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  
  /// * Check for blocked shortcuts and calculate metadata
  /// * 
  /// * This method checks if the route passes through restricted HOA areas
  /// * and calculates an alternative route if a shortcut exists
  /// * 
  /// * FUTURE (Post-MVP): Weather-aware rerouting logic
  /// * FUTURE (Post-MVP): Use PostGIS to check route intersection with restricted areas
  Future<RouteMetadata?> _checkBlockedShortcuts({
    required List<LatLng> routePoints,
    required List<String> userStickerIds,
    required List<String> restrictedHoaIds,
    required double allowedRouteDistance,
    required Duration allowedRouteDuration,
    required LatLng start,
    required LatLng end,
    required VehicleType vehicle,
    required bool avoidTolls,
  }) async {
    // * Find restricted HOAs that user doesn't have stickers for
    final blockedHoaIds = restrictedHoaIds
        .where((hoaId) => !userStickerIds.contains(hoaId))
        .toList();
    
    if (blockedHoaIds.isEmpty) {
      // * User has all required stickers
      return null;
    }
    
    // * FUTURE (Post-MVP): Check if route actually passes through restricted areas
    // * For MVP, we'll use a simplified check based on route proximity to HOA gates
    // * In production, this should use PostGIS to check if route segments intersect restricted areas
    
    // * For MVP, simulate blocked shortcut detection
    // * In real implementation, this would:
    // * 1. Check if route passes through restricted HOA boundaries
    // * 2. Calculate alternative route avoiding restricted areas
    // * 3. Compare time/distance difference
    
    // * Simplified MVP logic: Assume there's a potential shortcut if route is long
    // * and restricted HOAs exist between start and end
    final routeLength = allowedRouteDistance;
    final routeDurationMinutes = allowedRouteDuration.inMinutes;
    
    // * If route is longer than 5km, there might be a shortcut
    if (routeLength > 5.0) {
      // * Estimate potential time saved (15-30 minutes for long routes)
      final estimatedTimeSaved = (routeDurationMinutes * 0.2).round(); // * 20% time savings estimate
      
      // * For MVP, return metadata indicating a blocked shortcut exists
      // * In production, this would be calculated based on actual route comparison
      return RouteMetadata(
        blockedShortcut: true,
        hoaName: "Restricted Area", // * Will be replaced with actual HOA name
        timeSavedMinutes: estimatedTimeSaved > 0 ? estimatedTimeSaved : 15,
      );
    }
    
    return null;
  }
}
