/// * Hazard model representing a reported hazard
class HazardModel {
  final String id;
  final String userId;
  final String type;
  final String description;
  final String severity;
  final double lat;
  final double lng;
  final String? imageUrl;
  final DateTime createdAt;
  final String status;

  HazardModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.severity,
    required this.lat,
    required this.lng,
    this.imageUrl,
    required this.createdAt,
    this.status = "active",
  });

  /// * Create HazardModel from JSON
  factory HazardModel.fromJson(Map<String, dynamic> json) {
    return HazardModel(
      id: json["id"] as String,
      userId: json["user_id"] as String,
      type: json["type"] as String,
      description: json["description"] as String,
      severity: json["severity"] as String,
      lat: (json["lat"] as num).toDouble(),
      lng: (json["lng"] as num).toDouble(),
      imageUrl: json["image_url"] as String?,
      createdAt: DateTime.parse(json["created_at"] as String),
      status: json["status"] as String? ?? "active",
    );
  }

  /// * Convert HazardModel to JSON
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "type": type,
      "description": description,
      "severity": severity,
      "lat": lat,
      "lng": lng,
      "image_url": imageUrl,
      "created_at": createdAt.toIso8601String(),
      "status": status,
    };
  }

  /// * Create a copy with updated fields
  HazardModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? description,
    String? severity,
    double? lat,
    double? lng,
    String? imageUrl,
    DateTime? createdAt,
    String? status,
  }) {
    return HazardModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

