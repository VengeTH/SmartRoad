import "dart:math" as math;
import "package:latlong2/latlong.dart";
import "../services/routing_service.dart";

/// * Saved route model (Route as a Product)
class SavedRoute {
  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final List<LatLng> geometry; // * Decoded polyline points
  final LatLng startPoint;
  final LatLng endPoint;
  final int distanceMeters;
  final int estimatedDurationSeconds;
  final VehicleType vehicleType;
  final String? countryCode;
  final String? city;
  final Map<String, dynamic> tags; // * rain_safe, flood_safe, toll_free, etc.
  final int priceCents; // * 0 = free
  final String currencyCode;
  final bool isPublic;
  final bool isActive;
  final double trustScore; // * 0.0 to 100.0
  final int usageCount;
  final double ratingAvg; // * 0.0 to 5.0
  final int ratingCount;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastVerifiedAt;
  final DateTime? lastUsedAt;
  final Map<String, dynamic>? weatherAtSave;
  final int hazardCountAtSave;

  // * Optional creator info (from join)
  final String? creatorName;
  final String? creatorPhotoUrl;

  // * Optional purchase info (if user bought this route)
  final bool? isPurchased;
  final DateTime? purchasedAt;

  SavedRoute({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    required this.geometry,
    required this.startPoint,
    required this.endPoint,
    required this.distanceMeters,
    required this.estimatedDurationSeconds,
    required this.vehicleType,
    this.countryCode,
    this.city,
    Map<String, dynamic>? tags,
    this.priceCents = 0,
    this.currencyCode = "PHP",
    this.isPublic = true,
    this.isActive = true,
    this.trustScore = 0.0,
    this.usageCount = 0,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.lastVerifiedAt,
    this.lastUsedAt,
    this.weatherAtSave,
    this.hazardCountAtSave = 0,
    this.creatorName,
    this.creatorPhotoUrl,
    this.isPurchased,
    this.purchasedAt,
  }) : tags = tags ?? {};

  /// * Create SavedRoute from Supabase JSON
  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    // * Parse geometry (PostGIS LINESTRING)
    List<LatLng> geometry = [];
    if (json['geometry'] != null) {
      if (json['geometry'] is Map) {
        // * PostGIS returns as {"type": "LineString", "coordinates": [[lon, lat], ...]}
        final coords = json['geometry']['coordinates'] as List?;
        if (coords != null) {
          for (final coord in coords) {
            if (coord is List && coord.length >= 2) {
              geometry.add(
                LatLng(
                  (coord[1] as num).toDouble(), // * lat
                  (coord[0] as num).toDouble(), // * lon
                ),
              );
            }
          }
        }
      }
    }

    // * Parse start/end points
    LatLng startPoint = const LatLng(0, 0);
    LatLng endPoint = const LatLng(0, 0);

    if (json['start_point'] != null) {
      final start = json['start_point'];
      if (start is Map) {
        final coords = start['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          startPoint = LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
        }
      }
    }

    if (json['end_point'] != null) {
      final end = json['end_point'];
      if (end is Map) {
        final coords = end['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          endPoint = LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
        }
      }
    }

    // * Parse vehicle type
    VehicleType vehicleType;
    final vehicleStr = json['vehicle_type'] as String? ?? 'car';
    switch (vehicleStr) {
      case 'motorcycle':
        vehicleType = VehicleType.motorcycle;
        break;
      case 'big_bike':
        vehicleType = VehicleType.bigBike;
        break;
      case 'car':
        vehicleType = VehicleType.car;
        break;
      case 'truck':
        vehicleType = VehicleType.truck;
        break;
      case 'pedestrian':
        vehicleType = VehicleType.pedestrian;
        break;
      default:
        vehicleType = VehicleType.car;
    }

    // * Parse tags
    Map<String, dynamic> tags = {};
    if (json['tags'] != null) {
      if (json['tags'] is Map) {
        tags = Map<String, dynamic>.from(json['tags'] as Map);
      }
    }

    return SavedRoute(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      geometry: geometry,
      startPoint: startPoint,
      endPoint: endPoint,
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      estimatedDurationSeconds:
          (json['estimated_duration_seconds'] as num?)?.toInt() ?? 0,
      vehicleType: vehicleType,
      countryCode: json['country_code'] as String?,
      city: json['city'] as String?,
      tags: tags,
      priceCents: (json['price_cents'] as num?)?.toInt() ?? 0,
      currencyCode: json['currency_code'] as String? ?? "PHP",
      isPublic: json['is_public'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0.0,
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastVerifiedAt:
          json['last_verified_at'] != null
              ? DateTime.parse(json['last_verified_at'] as String)
              : null,
      lastUsedAt:
          json['last_used_at'] != null
              ? DateTime.parse(json['last_used_at'] as String)
              : null,
      weatherAtSave:
          json['weather_at_save'] != null
              ? Map<String, dynamic>.from(json['weather_at_save'] as Map)
              : null,
      hazardCountAtSave: (json['hazard_count_at_save'] as num?)?.toInt() ?? 0,
      creatorName: json['creator_name'] as String?,
      creatorPhotoUrl: json['creator_photo_url'] as String?,
      isPurchased: json['is_purchased'] as bool?,
      purchasedAt:
          json['purchased_at'] != null
              ? DateTime.parse(json['purchased_at'] as String)
              : null,
    );
  }

  /// * Convert SavedRoute to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    // * Convert geometry to PostGIS LINESTRING format
    final coordinates =
        geometry.map((point) => [point.longitude, point.latitude]).toList();

    return {
      'name': name,
      if (description != null) 'description': description,
      'geometry': {'type': 'LineString', 'coordinates': coordinates},
      'start_point': {
        'type': 'Point',
        'coordinates': [startPoint.longitude, startPoint.latitude],
      },
      'end_point': {
        'type': 'Point',
        'coordinates': [endPoint.longitude, endPoint.latitude],
      },
      'distance_meters': distanceMeters,
      'estimated_duration_seconds': estimatedDurationSeconds,
      'vehicle_type': _vehicleTypeToString(vehicleType),
      if (countryCode != null) 'country_code': countryCode,
      if (city != null) 'city': city,
      'tags': tags,
      'price_cents': priceCents,
      'currency_code': currencyCode,
      'is_public': isPublic,
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

  /// * Check if route is free
  bool get isFree => priceCents == 0;

  /// * Get formatted price
  String get formattedPrice {
    if (isFree) return "Free";
    // * PHP doesn't use cents, so priceCents is actually the price in PHP
    if (currencyCode == "PHP") {
      return "₱${priceCents.toStringAsFixed(0)}";
    }
    final price = priceCents / 100.0;
    return "$currencyCode ${price.toStringAsFixed(2)}";
  }

  /// * Get distance in kilometers
  double get distanceKm => distanceMeters / 1000.0;

  /// * Get duration as Duration object
  Duration get duration => Duration(seconds: estimatedDurationSeconds);

  /// * Check if route has specific tag
  bool hasTag(String tag) => tags[tag] == true;

  /// * Calculate distance to a point (for discovery)
  double distanceTo(LatLng point) {
    // * Find closest point on route
    double minDistance = double.infinity;
    for (final routePoint in geometry) {
      final dist = _haversineDistance(point, routePoint);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  double _haversineDistance(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(p2.latitude - p1.latitude);
    final double dLon = _toRadians(p2.longitude - p1.longitude);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(p1.latitude)) *
            math.cos(_toRadians(p2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}

/// * Route sharing mode enum
enum RouteSharingMode {
  strict, // * Follow exact route, no rerouting
  flexible, // * Allow rerouting only when blocked
  suggested, // * Use as suggestion, allow full rerouting
}

/// * Route share model
class RouteShare {
  final String id;
  final String routeId;
  final String shareToken;
  final RouteSharingMode sharingMode;
  final DateTime? expiresAt;
  final int viewCount;
  final DateTime createdAt;
  final String createdBy;

  RouteShare({
    required this.id,
    required this.routeId,
    required this.shareToken,
    required this.sharingMode,
    this.expiresAt,
    this.viewCount = 0,
    required this.createdAt,
    required this.createdBy,
  });

  factory RouteShare.fromJson(Map<String, dynamic> json) {
    RouteSharingMode mode;
    final modeStr = json['sharing_mode'] as String? ?? 'flexible';
    switch (modeStr) {
      case 'strict':
        mode = RouteSharingMode.strict;
        break;
      case 'flexible':
        mode = RouteSharingMode.flexible;
        break;
      case 'suggested':
        mode = RouteSharingMode.suggested;
        break;
      default:
        mode = RouteSharingMode.flexible;
    }

    return RouteShare(
      id: json['id'] as String,
      routeId: json['route_id'] as String,
      shareToken: json['share_token'] as String,
      sharingMode: mode,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.parse(json['expires_at'] as String)
              : null,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String,
    );
  }

  String get shareUrl => "smartroad://route/$shareToken";
  String get webShareUrl => "https://smartroad.app/route/$shareToken";
}
