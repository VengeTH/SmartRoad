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

/// * HOA (Homeowners Association) Model
/// * Represents a gate/community that requires stickers
class HOA {
  final String id;
  final String name;
  final String? description;
  final double? latitude; // * Gate location
  final double? longitude;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  HOA({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory HOA.fromJson(Map<String, dynamic> json) {
    return HOA(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
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

