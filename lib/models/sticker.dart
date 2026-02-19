/// * Digital Sticker Model
/// * Represents a user's HOA sticker/permit
import "dart:convert";

class Sticker {
  final String id;
  final String userId;
  final String hoaId;
  final String hoaName; // * e.g., "BF Resort", "BF Homes"
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool isActive;
  final bool isPhysicalSticker; // * True for uploaded physical stickers, False for in-app QR purchases
  final bool verifiedByAi; // * True if Gemini AI confirms the image looks like a sticker
  final String? stickerPhotoUrl; // * Path to the uploaded sticker image
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Sticker({
    required this.id,
    required this.userId,
    required this.hoaId,
    required this.hoaName,
    required this.issuedAt,
    required this.expiresAt,
    required this.isActive,
    this.isPhysicalSticker = false,
    this.verifiedByAi = false,
    this.stickerPhotoUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Sticker.fromJson(Map<String, dynamic> json) {
    return Sticker(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      hoaId: json['hoa_id'] as String,
      hoaName: json['hoa_name'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isActive: (json['is_active'] as bool?) ?? true,
      isPhysicalSticker: (json['is_physical_sticker'] as bool?) ?? false,
      verifiedByAi: (json['verified_by_ai'] as bool?) ?? false,
      stickerPhotoUrl: json['sticker_photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'hoa_id': hoaId,
      'hoa_name': hoaName,
      'issued_at': issuedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_active': isActive,
      'is_physical_sticker': isPhysicalSticker,
      'verified_by_ai': verifiedByAi,
      if (stickerPhotoUrl != null) 'sticker_photo_url': stickerPhotoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  /// * Check if sticker is currently valid (active and not expired)
  bool get isValid {
    final now = DateTime.now();
    return isActive && now.isBefore(expiresAt);
  }
  
  /// * Get days until expiration
  int get daysUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 0;
    return expiresAt.difference(now).inDays;
  }
}

/// * HOA Access Type Enum
enum HOAAccessType {
  publicShortcut,  // * Outsiders can buy a pass
  residentsOnly,   // * Outsiders CANNOT buy a pass
}

/// * HOA Pass Mode Enum
enum HOAPassMode {
  locationBound, // * Pass is valid only inside HOA geofence
  fullDay,       // * Pass is valid all day after entry scan
  both,          // * Guard can choose per scan
}

extension HOAPassModeExtension on HOAPassMode {
  String get value {
    switch (this) {
      case HOAPassMode.locationBound: return 'location_bound';
      case HOAPassMode.fullDay:       return 'full_day';
      case HOAPassMode.both:          return 'both';
    }
  }

  String get displayName {
    switch (this) {
      case HOAPassMode.locationBound: return 'Location-Bound';
      case HOAPassMode.fullDay:       return 'Day Pass';
      case HOAPassMode.both:          return 'Location-Bound / Day Pass';
    }
  }

  static HOAPassMode fromString(String? value) {
    switch (value) {
      case 'full_day':       return HOAPassMode.fullDay;
      case 'both':           return HOAPassMode.both;
      case 'location_bound':
      default:               return HOAPassMode.locationBound;
    }
  }
}

/// * HOA (Homeowners Association) Model
/// * Represents a gate/community that requires stickers
class HOA {
  final String id;
  final String name;
  final String? description;
  final double? latitude; // * Gate location
  final double? longitude;
  final HOAAccessType accessType; // * Access type: public_shortcut or residents_only
  final HOAPassMode passMode;    // * Pass mode: location_bound | full_day | both
  final int radiusMeters;         // * Geofence radius in meters for location_bound mode
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  HOA({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.accessType = HOAAccessType.publicShortcut,
    this.passMode = HOAPassMode.locationBound,
    this.radiusMeters = 500,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory HOA.fromJson(Map<String, dynamic> json) {
    // * Parse access_type from database (enum string)
    HOAAccessType accessType = HOAAccessType.publicShortcut;
    final accessTypeStr = json['access_type'] as String?;
    if (accessTypeStr != null) {
      switch (accessTypeStr) {
        case 'public_shortcut':
          accessType = HOAAccessType.publicShortcut;
          break;
        case 'residents_only':
          accessType = HOAAccessType.residentsOnly;
          break;
        default:
          accessType = HOAAccessType.publicShortcut;
      }
    }

    return HOA(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accessType: accessType,
      passMode: HOAPassModeExtension.fromString(json['pass_mode'] as String?),
      radiusMeters: (json['radius_meters'] as int?) ?? 500,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'access_type': accessType == HOAAccessType.publicShortcut
          ? 'public_shortcut'
          : 'residents_only',
      'pass_mode': passMode.value,
      'radius_meters': radiusMeters,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  /// * Check if outsiders can buy a pass for this HOA
  bool get allowsPublicAccess => accessType == HOAAccessType.publicShortcut;
  
  /// * Check if this HOA is strictly for residents only
  bool get isResidentsOnly => accessType == HOAAccessType.residentsOnly;
}

/// * Gate Pass QR Code Data Model
/// * Contains the data encoded in the QR code
class GatePassData {
  final String userId;
  final String stickerId;
  final int timestamp; // * Unix timestamp for security
  
  GatePassData({
    required this.userId,
    required this.stickerId,
    required this.timestamp,
  });
  
  /// * Create from current time
  factory GatePassData.now({
    required String userId,
    required String stickerId,
  }) {
    return GatePassData(
      userId: userId,
      stickerId: stickerId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  /// * Create from JSON string (decoded from QR)
  factory GatePassData.fromJsonString(String jsonString) {
    // * Parse JSON string using dart:convert
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    
    return GatePassData(
      userId: json['userId'] as String,
      stickerId: json['stickerId'] as String,
      timestamp: int.parse(json['timestamp'] as String),
    );
  }
  
  /// * Convert to JSON string for QR encoding
  String toJsonString() {
    return jsonEncode({
      'userId': userId,
      'stickerId': stickerId,
      'timestamp': timestamp.toString(),
    });
  }
  
  /// * Check if QR code is still valid (not too old - e.g., 5 minutes)
  bool isValid({Duration maxAge = const Duration(minutes: 5)}) {
    final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(qrTime) < maxAge;
  }
}

