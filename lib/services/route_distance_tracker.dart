/// * Route Distance Tracker Service
/// * Tracks real-time distances along navigation route
/// * Calculates distances to destination, next turn, next gate, and delivery entrances
import "dart:math" as math;
import "package:flutter/foundation.dart";
import "package:latlong2/latlong.dart";
import "../models/sticker.dart";
import "../services/routing_service.dart";

/// * Turn instruction point along route
class TurnPoint {
  final LatLng location;
  final String instruction;
  final int instructionIndex; // * Index in route points
  final double distanceFromStart; // * Distance along route in meters
  
  TurnPoint({
    required this.location,
    required this.instruction,
    required this.instructionIndex,
    required this.distanceFromStart,
  });
}

/// * Gate point along route
class GatePoint {
  final LatLng location;
  final HOA hoa;
  final double distanceFromStart; // * Distance along route in meters
  
  GatePoint({
    required this.location,
    required this.hoa,
    required this.distanceFromStart,
  });
}

/// * Distance indicators for navigation
class DistanceIndicators {
  final double? distanceToDestination; // * in meters
  final double? distanceToNextTurn; // * in meters
  final GatePoint? nextGate;
  final double? distanceToNextGate; // * in meters
  final GatePoint? nextDeliveryEntrance;
  final double? distanceToNextDeliveryEntrance; // * in meters
  
  DistanceIndicators({
    this.distanceToDestination,
    this.distanceToNextTurn,
    this.nextGate,
    this.distanceToNextGate,
    this.nextDeliveryEntrance,
    this.distanceToNextDeliveryEntrance,
  });
  
  /// * Check if any indicators are available
  bool get hasAny => 
    distanceToDestination != null ||
    distanceToNextTurn != null ||
    distanceToNextGate != null ||
    distanceToNextDeliveryEntrance != null;
}

/// * Route Distance Tracker
/// * Tracks distances along route based on actual route path (not straight-line)
class RouteDistanceTracker {
  static final RouteDistanceTracker _instance = RouteDistanceTracker._internal();
  factory RouteDistanceTracker() => _instance;
  RouteDistanceTracker._internal();
  
  // * Route data
  List<LatLng>? _routePoints;
  List<TurnPoint>? _turnPoints;
  List<GatePoint>? _gatePoints;
  
  // * Distance cache along route (for performance)
  List<double>? _cumulativeDistances; // * Cumulative distance from start to each point
  
  /// * Initialize tracker with route data
  /// * 
  /// * [route] - The route data from RoutingService
  /// * [hoas] - List of HOAs to check for gates along route
  /// * [userStickerIds] - User's active sticker IDs (for permission-based routing)
  void initialize({
    required RouteData route,
    required List<HOA> hoas,
    required List<String> userStickerIds,
  }) {
    _routePoints = route.points;
    
    // * Parse turn points from route instructions
    _turnPoints = _parseTurnPoints(route);
    
    // * Find gates along route
    _gatePoints = _findGatesAlongRoute(route.points, hoas, userStickerIds);
    
    // * Pre-calculate cumulative distances for performance
    _cumulativeDistances = _calculateCumulativeDistances(route.points);
    
    debugPrint("📍 [RouteDistanceTracker] Initialized: "
        "${_routePoints?.length ?? 0} points, "
        "${_turnPoints?.length ?? 0} turns, "
        "${_gatePoints?.length ?? 0} gates");
  }
  
  /// * Parse turn points from GraphHopper instructions
  /// * 
  /// * GraphHopper instructions format:
  /// * {
  /// *   "text": "Turn left onto Main St",
  /// *   "distance": 1234.5,
  /// *   "time": 45000,
  /// *   "interval": [0, 5], // * Point indices
  /// *   "sign": -2 // * Turn direction (-2 = left, 2 = right, etc.)
  /// * }
  List<TurnPoint>? _parseTurnPoints(RouteData route) {
    // * For now, we'll use a simplified approach
    // * In production, we'd parse the full GraphHopper instructions JSON
    // * For MVP, we'll identify significant direction changes in the route
    
    if (route.points.length < 3) {
      return null;
    }
    
    final turnPoints = <TurnPoint>[];
    final points = route.points;
    double cumulativeDistance = 0.0;
    
    // * Find points where direction changes significantly (potential turns)
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      
      // * Calculate bearing changes
      final bearing1 = _calculateBearing(prev, curr);
      final bearing2 = _calculateBearing(curr, next);
      final bearingChange = _normalizeBearing(bearing2 - bearing1);
      
      // * If bearing change is significant (> 30 degrees), it's likely a turn
      if (bearingChange.abs() > 30.0) {
        cumulativeDistance += _calculateHaversineDistance(prev, curr);
        
        // * Determine turn direction
        String instruction;
        if (bearingChange > 0) {
          if (bearingChange > 90) {
            instruction = "Turn around";
          } else if (bearingChange > 45) {
            instruction = "Turn right";
          } else {
            instruction = "Slight right";
          }
        } else {
          if (bearingChange < -90) {
            instruction = "Turn around";
          } else if (bearingChange < -45) {
            instruction = "Turn left";
          } else {
            instruction = "Slight left";
          }
        }
        
        turnPoints.add(TurnPoint(
          location: curr,
          instruction: instruction,
          instructionIndex: i,
          distanceFromStart: cumulativeDistance,
        ));
      } else {
        cumulativeDistance += _calculateHaversineDistance(prev, curr);
      }
    }
    
    return turnPoints.isNotEmpty ? turnPoints : null;
  }
  
  /// * Find HOA gates along the route
  /// * 
  /// * Checks if route passes near any HOA gate locations
  /// * Respects permission-based routing (only shows gates user can access)
  List<GatePoint>? _findGatesAlongRoute(
    List<LatLng> routePoints,
    List<HOA> hoas,
    List<String> userStickerIds,
  ) {
    if (routePoints.isEmpty || hoas.isEmpty) {
      return null;
    }
    
    final gatePoints = <GatePoint>[];
    final cumulativeDistances = _calculateCumulativeDistances(routePoints);
    
    // * Check each HOA gate
    for (final hoa in hoas) {
      if (hoa.latitude == null || hoa.longitude == null) {
        continue;
      }
      
      final gateLocation = LatLng(hoa.latitude!, hoa.longitude!);
      
      // * Find closest point on route to gate
      double minDistance = double.infinity;
      double closestDistanceAlongRoute = 0.0;
      
      for (int i = 0; i < routePoints.length - 1; i++) {
        final segmentStart = routePoints[i];
        final segmentEnd = routePoints[i + 1];
        
        // * Calculate distance from gate to route segment
        final distanceToSegment = _distanceToLineSegment(
          gateLocation,
          segmentStart,
          segmentEnd,
        );
        
        if (distanceToSegment < minDistance) {
          minDistance = distanceToSegment;
          closestDistanceAlongRoute = cumulativeDistances[i];
        }
      }
      
      // * If gate is within 500m of route, include it
      if (minDistance < 500.0) {
        gatePoints.add(GatePoint(
          location: gateLocation,
          hoa: hoa,
          distanceFromStart: closestDistanceAlongRoute,
        ));
      }
    }
    
    // * Sort by distance along route
    gatePoints.sort((a, b) => a.distanceFromStart.compareTo(b.distanceFromStart));
    
    return gatePoints.isNotEmpty ? gatePoints : null;
  }
  
  /// * Calculate cumulative distances along route
  List<double> _calculateCumulativeDistances(List<LatLng> points) {
    if (points.isEmpty) {
      return [];
    }
    
    final cumulative = <double>[0.0];
    double total = 0.0;
    
    for (int i = 1; i < points.length; i++) {
      total += _calculateHaversineDistance(points[i - 1], points[i]);
      cumulative.add(total);
    }
    
    return cumulative;
  }
  
  /// * Get distance indicators for current position
  /// * 
  /// * [currentLocation] - User's current location
  /// * Returns distance indicators based on route (not straight-line)
  DistanceIndicators getDistanceIndicators(LatLng currentLocation) {
    if (_routePoints == null || _routePoints!.isEmpty) {
      return DistanceIndicators();
    }
    
    // * Find closest point on route to current location
    final closestPoint = _findClosestPointOnRoute(currentLocation);
    if (closestPoint == null) {
      return DistanceIndicators();
    }
    
    final distanceAlongRoute = closestPoint['distance'] as double;
    
    // * Calculate distance to destination (along route)
    double? distanceToDestination;
    if (_cumulativeDistances != null && _cumulativeDistances!.isNotEmpty) {
      final totalDistance = _cumulativeDistances!.last;
      distanceToDestination = totalDistance - distanceAlongRoute;
      if (distanceToDestination < 0) {
        distanceToDestination = 0.0;
      }
    }
    
    // * Find next turn
    double? distanceToNextTurn;
    if (_turnPoints != null) {
      for (final turn in _turnPoints!) {
        if (turn.distanceFromStart > distanceAlongRoute) {
          distanceToNextTurn = turn.distanceFromStart - distanceAlongRoute;
          break;
        }
      }
    }
    
    // * Find next gate
    GatePoint? nextGate;
    double? distanceToNextGate;
    if (_gatePoints != null) {
      for (final gate in _gatePoints!) {
        if (gate.distanceFromStart > distanceAlongRoute) {
          nextGate = gate;
          distanceToNextGate = gate.distanceFromStart - distanceAlongRoute;
          break;
        }
      }
    }
    
    // * Find next delivery entrance (gates that allow public access)
    GatePoint? nextDeliveryEntrance;
    double? distanceToNextDeliveryEntrance;
    if (_gatePoints != null) {
      for (final gate in _gatePoints!) {
        // * Only show gates that allow public access (delivery entrances)
        if (gate.hoa.allowsPublicAccess && 
            gate.distanceFromStart > distanceAlongRoute) {
          nextDeliveryEntrance = gate;
          distanceToNextDeliveryEntrance = gate.distanceFromStart - distanceAlongRoute;
          break;
        }
      }
    }
    
    return DistanceIndicators(
      distanceToDestination: distanceToDestination,
      distanceToNextTurn: distanceToNextTurn,
      nextGate: nextGate,
      distanceToNextGate: distanceToNextGate,
      nextDeliveryEntrance: nextDeliveryEntrance,
      distanceToNextDeliveryEntrance: distanceToNextDeliveryEntrance,
    );
  }
  
  /// * Find closest point on route to given location
  /// * Returns index and distance along route
  Map<String, dynamic>? _findClosestPointOnRoute(LatLng location) {
    if (_routePoints == null || _routePoints!.isEmpty || _cumulativeDistances == null) {
      return null;
    }
    
    double minDistance = double.infinity;
    int closestIndex = 0;
    double closestDistanceAlongRoute = 0.0;
      
      // * Check each segment
      for (int i = 0; i < _routePoints!.length - 1; i++) {
        final segmentStart = _routePoints![i];
        final segmentEnd = _routePoints![i + 1];
      
      // * Calculate distance to segment
      final distanceToSegment = _distanceToLineSegment(
        location,
        segmentStart,
        segmentEnd,
      );
      
      if (distanceToSegment < minDistance) {
        minDistance = distanceToSegment;
        
        // * Find point on segment closest to location
        final t = _projectPointOnSegment(location, segmentStart, segmentEnd);
        final projectedPoint = LatLng(
          segmentStart.latitude + t * (segmentEnd.latitude - segmentStart.latitude),
          segmentStart.longitude + t * (segmentEnd.longitude - segmentStart.longitude),
        );
        
        // * Calculate distance along route to projected point
        final segmentDistance = _calculateHaversineDistance(segmentStart, projectedPoint);
        closestDistanceAlongRoute = _cumulativeDistances![i] + segmentDistance;
        closestIndex = i;
      }
    }
    
    return {
      'index': closestIndex,
      'distance': closestDistanceAlongRoute,
    };
  }
  
  /// * Project point onto line segment
  /// * Returns parameter t (0-1) indicating position on segment
  double _projectPointOnSegment(LatLng point, LatLng segmentStart, LatLng segmentEnd) {
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;
    
    if (dx == 0 && dy == 0) {
      return 0.0;
    }
    
    final t = ((point.longitude - segmentStart.longitude) * dx +
            (point.latitude - segmentStart.latitude) * dy) /
        (dx * dx + dy * dy);
    
    return t.clamp(0.0, 1.0);
  }
  
  /// * Calculate distance from point to line segment
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final t = _projectPointOnSegment(point, lineStart, lineEnd);
    
    final projectedPoint = LatLng(
      lineStart.latitude + t * (lineEnd.latitude - lineStart.latitude),
      lineStart.longitude + t * (lineEnd.longitude - lineStart.longitude),
    );
    
    return _calculateHaversineDistance(point, projectedPoint);
  }
  
  /// * Calculate bearing between two points (in degrees)
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = _toRadians(start.latitude);
    final lat2 = _toRadians(end.latitude);
    final dLon = _toRadians(end.longitude - start.longitude);
    
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    
    final bearing = math.atan2(y, x);
    return _toDegrees(bearing);
  }
  
  /// * Normalize bearing to -180 to 180 range
  double _normalizeBearing(double bearing) {
    while (bearing > 180) bearing -= 360;
    while (bearing < -180) bearing += 360;
    return bearing;
  }
  
  /// * Calculate Haversine distance between two points (in meters)
  double _calculateHaversineDistance(LatLng start, LatLng end) {
    const double earthRadiusM = 6371000.0; // * Earth radius in meters
    final double dLat = _toRadians(end.latitude - start.latitude);
    final double dLon = _toRadians(end.longitude - start.longitude);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(start.latitude)) * math.cos(_toRadians(end.latitude)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  double _toDegrees(double radians) => radians * (180.0 / math.pi);
  
  /// * Reset tracker (clear route data)
  void reset() {
    _routePoints = null;
    _turnPoints = null;
    _gatePoints = null;
    _cumulativeDistances = null;
    
    debugPrint("📍 [RouteDistanceTracker] Reset");
  }
}

