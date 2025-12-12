/// * Route calculation utilities
import "dart:math" as math;
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";

/// * Calculate minimum distance from a point to a route (in meters)
/// * 
/// * [point] - The point to measure from
/// * [route] - List of route points
/// * 
/// Returns the minimum distance in meters
double calculateDistanceToRoute(LatLng point, List<LatLng> route) {
  if (route.isEmpty) {
    return double.infinity;
  }
  
  double minDistance = double.infinity;
  
  // * Check distance to each point on the route
  for (final routePoint in route) {
    final distance = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      routePoint.latitude,
      routePoint.longitude,
    );
    
    if (distance < minDistance) {
      minDistance = distance;
    }
  }
  
  // * Also check distance to segments between points
  for (int i = 0; i < route.length - 1; i++) {
    final segmentStart = route[i];
    final segmentEnd = route[i + 1];
    
    final distanceToSegment = _distanceToSegment(
      point,
      segmentStart,
      segmentEnd,
    );
    
    if (distanceToSegment < minDistance) {
      minDistance = distanceToSegment;
    }
  }
  
  return minDistance;
}

/// * Calculate distance from a point to a line segment (in meters)
/// * Uses perpendicular distance if point projects onto segment, otherwise uses endpoint distance
double _distanceToSegment(LatLng point, LatLng segmentStart, LatLng segmentEnd) {
  // * Calculate distances
  final distToStart = Geolocator.distanceBetween(
    point.latitude,
    point.longitude,
    segmentStart.latitude,
    segmentStart.longitude,
  );
  
  final distToEnd = Geolocator.distanceBetween(
    point.latitude,
    point.longitude,
    segmentEnd.latitude,
    segmentEnd.longitude,
  );
  
  final segmentLength = Geolocator.distanceBetween(
    segmentStart.latitude,
    segmentStart.longitude,
    segmentEnd.latitude,
    segmentEnd.longitude,
  );
  
  // * If segment is very short, return distance to closest endpoint
  if (segmentLength < 1.0) {
    return distToStart < distToEnd ? distToStart : distToEnd;
  }
  
  // * Calculate bearing from start to end
  final bearing = Geolocator.bearingBetween(
    segmentStart.latitude,
    segmentStart.longitude,
    segmentEnd.latitude,
    segmentEnd.longitude,
  );
  
  // * Calculate bearing from start to point
  final bearingToPoint = Geolocator.bearingBetween(
    segmentStart.latitude,
    segmentStart.longitude,
    point.latitude,
    point.longitude,
  );
  
  // * Calculate angle difference
  double angleDiff = (bearingToPoint - bearing).abs();
  if (angleDiff > 180) {
    angleDiff = 360 - angleDiff;
  }
  
    // * If angle is close to 90 degrees, point projects onto segment
    // * Otherwise, use distance to closest endpoint
    if (angleDiff > 45 && angleDiff < 135) {
      // * Point projects onto segment - calculate perpendicular distance
      final angleRad = angleDiff * math.pi / 180;
      final perpendicularDist = distToStart * math.sin(angleRad).abs();
      return perpendicularDist;
    } else {
      // * Use distance to closest endpoint
      return distToStart < distToEnd ? distToStart : distToEnd;
    }
}

/// * Find the closest point on a route to a given point
/// * 
/// * [point] - The point to find closest route point for
/// * [route] - List of route points
/// * 
/// Returns the closest route point
LatLng findClosestPointOnRoute(LatLng point, List<LatLng> route) {
  if (route.isEmpty) {
    return point;
  }
  
  LatLng closestPoint = route[0];
  double minDistance = Geolocator.distanceBetween(
    point.latitude,
    point.longitude,
    closestPoint.latitude,
    closestPoint.longitude,
  );
  
  for (final routePoint in route) {
    final distance = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      routePoint.latitude,
      routePoint.longitude,
    );
    
    if (distance < minDistance) {
      minDistance = distance;
      closestPoint = routePoint;
    }
  }
  
  return closestPoint;
}

/// * Split route into traveled and upcoming segments based on current position
/// * 
/// * [route] - Complete route
/// * [currentPosition] - Current user position
/// * [thresholdKm] - Distance threshold in km to determine split point (default 1km)
/// * 
/// Returns a map with 'traveled' and 'upcoming' route segments
Map<String, List<LatLng>> splitRouteAtPoint(
  List<LatLng> route,
  LatLng currentPosition, {
  double thresholdKm = 1.0,
}) {
  if (route.isEmpty) {
    return {
      'traveled': <LatLng>[],
      'upcoming': <LatLng>[],
    };
  }
  
  // * Find closest point on route
  int closestIndex = 0;
  double minDistance = double.infinity;
  
  for (int i = 0; i < route.length; i++) {
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      route[i].latitude,
      route[i].longitude,
    );
    
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }
  
  // * Calculate distance from start to closest point
  double distanceFromStart = 0.0;
  for (int i = 0; i < closestIndex; i++) {
    distanceFromStart += Geolocator.distanceBetween(
      route[i].latitude,
      route[i].longitude,
      route[i + 1].latitude,
      route[i + 1].longitude,
    );
  }
  
  // * If user is more than thresholdKm from start, split the route
  // * Otherwise, all route is upcoming
  if (distanceFromStart >= thresholdKm * 1000) {
    // * Split at closest point
    final traveled = route.sublist(0, closestIndex + 1);
    final upcoming = route.sublist(closestIndex);
    
    return {
      'traveled': traveled,
      'upcoming': upcoming,
    };
  } else {
    // * All route is upcoming
    return {
      'traveled': <LatLng>[],
      'upcoming': route,
    };
  }
}

/// * Calculate route progress percentage
/// * 
/// * [route] - Complete route
/// * [currentPosition] - Current user position
/// * 
/// Returns progress as a percentage (0.0 to 1.0)
double calculateRouteProgress(List<LatLng> route, LatLng currentPosition) {
  if (route.length < 2) {
    return 0.0;
  }
  
  // * Find closest point on route
  int closestIndex = 0;
  double minDistance = double.infinity;
  
  for (int i = 0; i < route.length; i++) {
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      route[i].latitude,
      route[i].longitude,
    );
    
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }
  
  // * Calculate total route distance
  double totalDistance = 0.0;
  for (int i = 0; i < route.length - 1; i++) {
    totalDistance += Geolocator.distanceBetween(
      route[i].latitude,
      route[i].longitude,
      route[i + 1].latitude,
      route[i + 1].longitude,
    );
  }
  
  // * Calculate distance traveled
  double traveledDistance = 0.0;
  for (int i = 0; i < closestIndex; i++) {
    traveledDistance += Geolocator.distanceBetween(
      route[i].latitude,
      route[i].longitude,
      route[i + 1].latitude,
      route[i + 1].longitude,
    );
  }
  
  if (totalDistance == 0.0) {
    return 0.0;
  }
  
  return (traveledDistance / totalDistance).clamp(0.0, 1.0);
}

/// * Calculate remaining distance along route from current position
/// * 
/// * [route] - Complete route
/// * [currentPosition] - Current user position
/// * 
/// Returns remaining distance in meters
double calculateRemainingDistance(List<LatLng> route, LatLng currentPosition) {
  if (route.length < 2) {
    return 0.0;
  }
  
  // * Find closest point on route
  int closestIndex = 0;
  double minDistance = double.infinity;
  
  for (int i = 0; i < route.length; i++) {
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      route[i].latitude,
      route[i].longitude,
    );
    
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }
  
  // * Calculate remaining distance from closest point to end
  double remainingDistance = 0.0;
  for (int i = closestIndex; i < route.length - 1; i++) {
    remainingDistance += Geolocator.distanceBetween(
      route[i].latitude,
      route[i].longitude,
      route[i + 1].latitude,
      route[i + 1].longitude,
    );
  }
  
  return remainingDistance;
}

