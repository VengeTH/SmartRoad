import "dart:math" as math;

/// * Hazard model representing a road hazard report
class Hazard {
  final String id;
  final String userId;
  final HazardType type;
  final String description;
  final SeverityLevel severity;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? stickerFlag;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // * Optional user info (from join)
  final String? userName;
  final String? userPhotoUrl;
  
  Hazard({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.severity,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.stickerFlag,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userPhotoUrl,
  });
  
  /// * Create Hazard from Supabase JSON
  factory Hazard.fromJson(Map<String, dynamic> json) {
    // * Parse location (PostGIS geography point)
    double lat = 0.0;
    double lon = 0.0;
    
    if (json['location'] != null) {
      if (json['location'] is Map) {
        // * PostGIS returns as {"type": "Point", "coordinates": [lon, lat]}
        final coords = json['location']['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      } else if (json['location'] is String) {
        // * Handle WKT format if needed
        final wkt = json['location'] as String;
        final match = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)').firstMatch(wkt);
        if (match != null) {
          lon = double.parse(match.group(1)!);
          lat = double.parse(match.group(2)!);
        }
      }
    }
    
    return Hazard(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: HazardType.fromString(json['type'] as String),
      description: json['description'] as String,
      severity: SeverityLevel.fromString(json['severity'] as String),
      latitude: lat,
      longitude: lon,
      imageUrl: json['image_url'] as String?,
      stickerFlag: json['sticker_flag'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userPhotoUrl: json['user_photo_url'] as String?,
    );
  }
  
  /// * Convert Hazard to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'description': description,
      'severity': severity.value,
      'location': 'POINT($longitude $latitude)',
      if (imageUrl != null) 'image_url': imageUrl,
      if (stickerFlag != null) 'sticker_flag': stickerFlag,
    };
  }
  
  /// * Calculate distance to another point (Haversine formula)
  double distanceTo(double lat, double lon) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRadians(lat - latitude);
    final double dLon = _toRadians(lon - longitude);
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(latitude)) * math.cos(_toRadians(lat)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}

/// * Hazard type enum
enum HazardType {
  pothole('pothole'),
  flood('flood'),
  accident('accident'),
  closure('closure'),
  landslide('landslide'),
  roadblock('roadblock'),
  fallenTree('fallen_tree'),
  traffic('traffic'),
  debris('debris');
  
  final String value;
  const HazardType(this.value);
  
  static HazardType fromString(String value) {
    return HazardType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HazardType.roadblock,
    );
  }
}

/// * Severity level enum
enum SeverityLevel {
  low('Low'),
  medium('Medium'),
  high('High');
  
  final String value;
  const SeverityLevel(this.value);
  
  static SeverityLevel fromString(String value) {
    return SeverityLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SeverityLevel.medium,
    );
  }
}

