/// * Routing Service
/// * Integrates with GraphHopper for route calculation
import "dart:math" as math;
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "dart:convert";
import "package:latlong2/latlong.dart";
import "package:flutter/foundation.dart";

/// * Vehicle type enum
enum VehicleType {
  bigBike("Big Bike (400cc+)"),
  motorcycle("Motorcycle (≤399cc)"),
  car("Car (Private)"),
  truck("Truck"),
  pedestrian("Pedestrian");
  
  final String value;
  const VehicleType(this.value);
  
  /// * Get GraphHopper vehicle parameter
  String get graphhopperParam {
    switch (this) {
      case VehicleType.bigBike:
      case VehicleType.motorcycle:
        return "motorcycle";
      case VehicleType.car:
        return "car";
      case VehicleType.truck:
        return "truck";
      case VehicleType.pedestrian:
        return "foot";
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
    }
  }
}

/// * Route data model
class RouteData {
  final List<LatLng> points;
  final double distance; // * in kilometers
  final Duration duration;
  final String? instructions;
  
  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    this.instructions,
  });
}

/// * Routing service for calculating routes
class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();
  
  // * GraphHopper API endpoint (local Docker instance)
  static const String _graphhopperUrl = "http://localhost:8989";
  
  /// * Calculate route between two points
  Future<RouteData> calculateRoute({
    required LatLng start,
    required LatLng end,
    required VehicleType vehicle,
    bool avoidTolls = true,
  }) async {
    try {
      // * Build GraphHopper API URL
      final vehicleParam = vehicle.graphhopperParam;
      final url = Uri.parse(
        "$_graphhopperUrl/route"
        "?point=${start.latitude},${start.longitude}"
        "&point=${end.latitude},${end.longitude}"
        "&vehicle=$vehicleParam"
        "&type=json"
        "&instructions=true"
        "&calc_points=true"
        "&points_encoded=false"
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SmartRoad App',
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
        
        // * Parse duration (in milliseconds, convert to Duration)
        final durationMs = (path['time'] as num?)?.toInt() ?? 0;
        final duration = Duration(milliseconds: durationMs);
        
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
        
        return RouteData(
          points: routePoints,
          distance: distanceKm,
          duration: duration,
          instructions: instructions,
        );
      } else {
        throw Exception("GraphHopper API error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Routing error: $e");
      // * Return a fallback route (straight line) if GraphHopper is unavailable
      return _createFallbackRoute(start, end, vehicle);
    }
  }
  
  /// * Create a fallback route (straight line) when GraphHopper is unavailable
  RouteData _createFallbackRoute(LatLng start, LatLng end, VehicleType vehicle) {
    // * Simple straight line route
    final points = [start, end];
    
    // * Calculate distance using Haversine formula
    final distance = _calculateDistance(start, end);
    
    // * Estimate duration based on vehicle type
    double avgSpeed;
    switch (vehicle) {
      case VehicleType.bigBike:
        avgSpeed = 50.0; // * km/h
        break;
      case VehicleType.motorcycle:
        avgSpeed = 40.0;
        break;
      case VehicleType.car:
        avgSpeed = 45.0;
        break;
      case VehicleType.truck:
        avgSpeed = 35.0;
        break;
      case VehicleType.pedestrian:
        avgSpeed = 5.0;
        break;
    }
    final durationMinutes = (distance / avgSpeed * 60).round();
    final duration = Duration(minutes: durationMinutes);
    
    return RouteData(
      points: points,
      distance: distance,
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
}
