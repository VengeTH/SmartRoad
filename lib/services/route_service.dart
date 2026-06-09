import "dart:math" as math;
import "package:flutter/foundation.dart";
import "../models/saved_route.dart";
import "../core/config/env.dart";
import "../services/supabase_service.dart";
import "../services/database_service.dart";
import "../services/routing_service.dart";
import "package:latlong2/latlong.dart";

/// * Service for Route as a Product operations
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();
  
  bool _isInitialized = false;
  
  /// * Check if running in demo mode
  bool get isDemoMode => !_isInitialized || !Env.validate();
  
  /// * Get database service client (null in demo mode)
  DatabaseService? get client {
    if (isDemoMode || !_isInitialized) {
      return null;
    }
    try {
      return SupabaseService().client;
    } catch (e) {
      return null;
    }
  }
  
  /// * Initialize service
  Future<void> initialize() async {
    if (!Env.validate()) {
      debugPrint("⚠️ Demo mode: RouteService not initialized");
      _isInitialized = false;
      return;
    }
    _isInitialized = true;
  }
  
  // * ========================================================================
  // * ROUTE CREATION (Navigation-First)
  // * ========================================================================
  
  /// * Save current navigation route
  /// * 
  /// * This is called when user taps "Save this route" during navigation
  /// * The actual driven polyline is stored (not recalculated)
  Future<SavedRoute> saveCurrentRoute({
    required String name,
    String? description,
    required List<LatLng> geometry, // * Actual driven route
    required LatLng startPoint,
    required LatLng endPoint,
    required int distanceMeters,
    required int estimatedDurationSeconds,
    required VehicleType vehicleType,
    String? countryCode,
    String? city,
    Map<String, dynamic>? tags,
    int priceCents = 0,
    bool isPublic = true,
  }) async {
    if (isDemoMode) {
      throw Exception("Saving routes not available in demo mode");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    
    // * Get current user
    final userId = c.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User must be authenticated to save routes");
    }
    
    // * Snapshot current conditions
    final weatherAtSave = await _snapshotWeatherConditions(startPoint);
    final hazardCount = await _countHazardsNearRoute(geometry);
    
    // * Build route data
    final routeData = {
      'name': name,
      if (description != null) 'description': description,
      'geometry': _geometryToPostGIS(geometry),
      'start_point': _pointToPostGIS(startPoint),
      'end_point': _pointToPostGIS(endPoint),
      'distance_meters': distanceMeters,
      'estimated_duration_seconds': estimatedDurationSeconds,
      'vehicle_type': _vehicleTypeToString(vehicleType),
      if (countryCode != null) 'country_code': countryCode,
      if (city != null) 'city': city,
      'tags': tags ?? {},
      'price_cents': priceCents,
      'currency_code': 'PHP',
      'is_public': isPublic,
      'weather_at_save': weatherAtSave,
      'hazard_count_at_save': hazardCount,
    };
    
    // * Insert route
    final response = await c
        .from('saved_routes')
        .insert(routeData)
        .select()
        .single();
    
    return SavedRoute.fromJson(response);
  }
  
  /// * Save partial route (user saves mid-navigation)
  Future<SavedRoute> savePartialRoute({
    required String name,
    required List<LatLng> traveledGeometry, // * Route traveled so far
    required LatLng startPoint,
    required LatLng currentPoint,
    required VehicleType vehicleType,
    // * ... other params
  }) async {
    // * Similar to saveCurrentRoute, but mark as incomplete
    // * User can complete it later
    final route = await saveCurrentRoute(
      name: name,
      geometry: traveledGeometry,
      startPoint: startPoint,
      endPoint: currentPoint, // * Current position as end
      distanceMeters: _calculateDistanceMeters(traveledGeometry),
      estimatedDurationSeconds: 0, // * Will be updated when completed
      vehicleType: vehicleType,
      isPublic: false, // * Partial routes are private by default
    );
    
    // * Mark as incomplete (would need is_complete field in schema)
    // * For MVP, we'll just save it and user can update later
    
    return route;
  }
  
  // * ========================================================================
  // * ROUTE DISCOVERY (Inside Navigation)
  // * ========================================================================
  
  /// * Discover routes near location
  Future<List<SavedRoute>> discoverRoutesNearby({
    required LatLng location,
    double radiusMeters = 5000,
    VehicleType? vehicleType,
    List<String>? requiredTags, // * e.g., ['rain_safe', 'flood_safe']
    int limit = 10,
    String sortBy = 'trust_score', // * trust_score, usage_count, rating_avg
  }) async {
    if (isDemoMode) {
      return [];
    }
    final c = client;
    if (c == null) {
      return [];
    }
    
    // * Build query
    // * Note: Spatial filtering (ST_DWithin) must be done via RPC function
    // * For MVP, we'll fetch routes and filter client-side
    // * In production, use PostGIS RPC function
    
    var query = c
        .from('saved_routes')
        .select()
        .eq('is_public', true)
        .eq('is_active', true);
    
    // * Filter by vehicle type
    if (vehicleType != null) {
      query = query.eq('vehicle_type', _vehicleTypeToString(vehicleType));
    }
    
    // * Apply limit
    final response = await query.limit(limit);
    
    final List<SavedRoute> routes = [];
    for (final item in response) {
      try {
        final route = SavedRoute.fromJson(item);
        
        // * Filter by tags (client-side for MVP)
        bool matchesTags = true;
        if (requiredTags != null && requiredTags.isNotEmpty) {
          for (final tag in requiredTags) {
            if (!route.hasTag(tag)) {
              matchesTags = false;
              break;
            }
          }
        }
        
        if (!matchesTags) continue;
        
        // * Filter by distance (client-side for MVP)
        final distanceToRoute = route.distanceTo(location);
        if (distanceToRoute * 1000 <= radiusMeters) {
          routes.add(route);
        }
      } catch (e) {
        debugPrint("Error parsing route: $e");
      }
    }
    
    // * Sort
    routes.sort((a, b) {
      switch (sortBy) {
        case 'usage_count':
          return b.usageCount.compareTo(a.usageCount);
        case 'rating_avg':
          return b.ratingAvg.compareTo(a.ratingAvg);
        case 'trust_score':
        default:
          return b.trustScore.compareTo(a.trustScore);
      }
    });
    
    return routes.take(limit).toList();
  }
  
  /// * Get popular routes for specific conditions
  Future<List<SavedRoute>> getPopularRoutesForConditions({
    required LatLng location,
    bool rainSafe = false,
    bool floodSafe = false,
    bool nightSafe = false,
    VehicleType? vehicleType,
    int limit = 5,
  }) async {
    final tags = <String>[];
    if (rainSafe) tags.add('rain_safe');
    if (floodSafe) tags.add('flood_safe');
    if (nightSafe) tags.add('night_safe');
    
    return discoverRoutesNearby(
      location: location,
      requiredTags: tags.isNotEmpty ? tags : null,
      vehicleType: vehicleType,
      sortBy: 'usage_count',
      limit: limit,
    );
  }
  
  // * ========================================================================
  // * ROUTE ACCESS (Preview vs Full)
  // * ========================================================================
  
  /// * Get route details
  /// * Returns preview for unpaid routes, full geometry for free/purchased
  Future<SavedRoute?> getRoute(String routeId, {bool includeGeometry = false}) async {
    if (isDemoMode) {
      return null;
    }
    final c = client;
    if (c == null) {
      return null;
    }
    
    // * Check if user purchased this route
    final userId = c.auth.currentUser?.id;
    bool isPurchased = false;
    DateTime? purchasedAt;
    
    if (userId != null) {
      final purchase = await c
          .from('route_purchases')
          .select()
          .eq('route_id', routeId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (purchase != null) {
        isPurchased = true;
        purchasedAt = purchase['purchased_at'] != null
            ? DateTime.parse(purchase['purchased_at'] as String)
            : null;
      }
    }
    
    // * Get route
    final response = await c
        .from('saved_routes')
        .select('''
          *,
          profiles:creator_id (
            name,
            photo_url
          )
        ''')
        .eq('id', routeId)
        .maybeSingle();
    
    if (response == null) return null;
    
    final routeJson = Map<String, dynamic>.from(response);
    final profileData = routeJson['profiles'] as Map<String, dynamic>?;
    
    if (profileData != null) {
      routeJson['creator_name'] = profileData['name'];
      routeJson['creator_photo_url'] = profileData['photo_url'];
    }
    
    routeJson['is_purchased'] = isPurchased;
    if (purchasedAt != null) {
      routeJson['purchased_at'] = purchasedAt.toIso8601String();
    }
    
    // * If route is paid and not purchased, don't include geometry
    final priceCents = (routeJson['price_cents'] as num?)?.toInt() ?? 0;
    if (priceCents > 0 && !isPurchased && !includeGeometry) {
      // * Remove geometry from response
      routeJson['geometry'] = null;
    }
    
    return SavedRoute.fromJson(routeJson);
  }
  
  // * ========================================================================
  // * ROUTE PURCHASE
  // * ========================================================================
  
  /// * Purchase a paid route
  /// * Payment logic is abstracted (no real payment integration yet)
  Future<void> purchaseRoute(String routeId) async {
    if (isDemoMode) {
      throw Exception("Purchasing routes not available in demo mode");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    
    final userId = c.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User must be authenticated to purchase routes");
    }
    
    // * Check if already purchased
    final existing = await c
        .from('route_purchases')
        .select()
        .eq('route_id', routeId)
        .eq('user_id', userId)
        .maybeSingle();
    
    if (existing != null) {
      throw Exception("Route already purchased");
    }
    
    // * Get route to check price
    final route = await c
        .from('saved_routes')
        .select('price_cents, currency_code')
        .eq('id', routeId)
        .single();
    
    final priceCents = (route['price_cents'] as num?)?.toInt() ?? 0;
    if (priceCents == 0) {
      throw Exception("Route is free, no purchase needed");
    }
    
    // * TODO: Process payment (abstracted for MVP)
    // * For now, just insert purchase record
    
    await c.from('route_purchases').insert({
      'route_id': routeId,
      'user_id': userId,
      'price_paid_cents': priceCents,
      'currency_code': route['currency_code'] ?? 'PHP',
    });
  }
  
  // * ========================================================================
  // * ROUTE SHARING
  // * ========================================================================
  
  /// * Create shareable link for route
  Future<RouteShare> shareRoute({
    required String routeId,
    required RouteSharingMode sharingMode,
    DateTime? expiresAt,
  }) async {
    if (isDemoMode) {
      throw Exception("Sharing routes not available in demo mode");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    
    final userId = c.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User must be authenticated to share routes");
    }
    
    // * Verify user owns the route
    final route = await c
        .from('saved_routes')
        .select('creator_id')
        .eq('id', routeId)
        .single();
    
    if (route['creator_id'] != userId) {
      throw Exception("Only route creator can share routes");
    }
    
    // * Generate share token (simple hex for MVP)
    final token = _generateShareToken();
    
    // * Insert share record
    final response = await c
        .from('route_shares')
        .insert({
          'route_id': routeId,
          'share_token': token,
          'sharing_mode': _sharingModeToString(sharingMode),
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();
    
    return RouteShare.fromJson(response);
  }
  
  /// * Get route from share token
  Future<SavedRoute?> getRouteFromShareToken(String shareToken) async {
    if (isDemoMode) {
      return null;
    }
    final c = client;
    if (c == null) {
      return null;
    }
    
    // * Get share record
    final share = await c
        .from('route_shares')
        .select()
        .eq('share_token', shareToken)
        .maybeSingle();
    
    if (share == null) {
      return null;
    }
    
    // * Check expiration
    if (share['expires_at'] != null) {
      final expiresAt = DateTime.parse(share['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        return null; // * Expired
      }
    }
    
    // * Increment view count
    await c
        .from('route_shares')
        .update({'view_count': (share['view_count'] as int? ?? 0) + 1})
        .eq('id', share['id']);
    
    // * Get route (always include geometry for shared routes)
    return getRoute(share['route_id'] as String, includeGeometry: true);
  }
  
  // * ========================================================================
  // * ROUTE USAGE TRACKING
  // * ========================================================================
  
  /// * Log route usage start
  Future<String> startRouteUsage(String routeId) async {
    if (isDemoMode) {
      return "demo-usage-id";
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    
    final userId = c.auth.currentUser?.id;
    
    final response = await c
        .from('route_usage_log')
        .insert({
          'route_id': routeId,
          if (userId != null) 'user_id': userId,
        })
        .select()
        .single();
    
    // * Increment usage count
    await c.rpc('increment_route_usage', params: {'route_uuid': routeId});
    
    return response['id'] as String;
  }
  
  /// * Log route completion
  Future<void> completeRouteUsage({
    required String usageLogId,
    required double completionPercentage,
    int deviationCount = 0,
    bool wasValid = true,
  }) async {
    if (isDemoMode) {
      return;
    }
    final c = client;
    if (c == null) {
      return;
    }
    
    await c
        .from('route_usage_log')
        .update({
          'completed_at': DateTime.now().toIso8601String(),
          'completion_percentage': completionPercentage,
          'deviation_count': deviationCount,
          'was_valid': wasValid,
        })
        .eq('id', usageLogId);
  }
  
  // * ========================================================================
  // * ROUTE RATINGS
  // * ========================================================================
  
  /// * Rate a route
  Future<void> rateRoute({
    required String routeId,
    required int rating, // * 1-5
    String? comment,
  }) async {
    if (isDemoMode) {
      return;
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    
    final userId = c.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User must be authenticated to rate routes");
    }
    
    if (rating < 1 || rating > 5) {
      throw Exception("Rating must be between 1 and 5");
    }
    
    // * Upsert rating
    await c
        .from('route_ratings')
        .upsert({
          'route_id': routeId,
          'user_id': userId,
          'rating': rating,
          if (comment != null) 'comment': comment,
        });
    
    // * Rating stats are updated via trigger
  }
  
  // * ========================================================================
  // * HELPER METHODS
  // * ========================================================================
  
  Map<String, dynamic> _geometryToPostGIS(List<LatLng> points) {
    return {
      'type': 'LineString',
      'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
    };
  }
  
  Map<String, dynamic> _pointToPostGIS(LatLng point) {
    return {
      'type': 'Point',
      'coordinates': [point.longitude, point.latitude],
    };
  }
  
  String _vehicleTypeToString(VehicleType type) {
    switch (type) {
      case VehicleType.motorcycle:
        return 'motorcycle';
      case VehicleType.bigBike:
        return 'big_bike';
      case VehicleType.car:
        return 'car';
      case VehicleType.truck:
        return 'truck';
      case VehicleType.pedestrian:
        return 'pedestrian';
      case VehicleType.deliveryRider:
        return 'delivery_rider';
      case VehicleType.floodSafe:
        return 'flood_safe';
      case VehicleType.weatherSafe:
        return 'weather_safe';
      case VehicleType.hoaAccess:
        return 'hoa_access';
    }
  }
  
  String _sharingModeToString(RouteSharingMode mode) {
    switch (mode) {
      case RouteSharingMode.strict:
        return 'strict';
      case RouteSharingMode.flexible:
        return 'flexible';
      case RouteSharingMode.suggested:
        return 'suggested';
    }
  }
  
  String _generateShareToken() {
    // * Simple hex token for MVP
    // * In production, use more secure token generation
    final random = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return random.substring(random.length - 22);
  }
  
  int _calculateDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _haversineDistance(points[i], points[i + 1]);
    }
    return (totalDistance * 1000).round();
  }
  
  double _haversineDistance(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(p2.latitude - p1.latitude);
    final double dLon = _toRadians(p2.longitude - p1.longitude);
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(p1.latitude)) * math.cos(_toRadians(p2.latitude)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  
  Future<Map<String, dynamic>> _snapshotWeatherConditions(LatLng location) async {
    // * Get current weather conditions
    // * This is a placeholder - integrate with your weather service
    try {
      // * TODO: Call weather service
      return {
        'rain': false,
        'flood_risk': 'low',
        'visibility': 'good',
      };
    } catch (e) {
      return {};
    }
  }
  
  Future<int> _countHazardsNearRoute(List<LatLng> geometry) async {
    // * Count hazards within 100m of route
    // * This is a placeholder - integrate with hazards service
    try {
      // * TODO: Query hazards near route geometry
      return 0;
    } catch (e) {
      return 0;
    }
  }
}


