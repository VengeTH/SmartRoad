/// * Moderation status for user-submitted place photos.
enum PlaceImageStatus {
  pending("pending"),
  approved("approved"),
  rejected("rejected");

  final String value;
  const PlaceImageStatus(this.value);

  static PlaceImageStatus fromString(String value) {
    return PlaceImageStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => PlaceImageStatus.pending,
    );
  }
}

/// * Place photo model (user-submitted + admin-reviewed).
class PlaceImage {
  final String id;
  final String placeId;
  final String userId;
  final String imageUrl;
  final PlaceImageStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // * Optional user info (from join)
  final String? userName;
  final String? userPhotoUrl;

  // * Optional review info
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewReason;

  PlaceImage({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userPhotoUrl,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewReason,
  });

  factory PlaceImage.fromJson(Map<String, dynamic> json) {
    return PlaceImage(
      id: json["id"] as String,
      placeId: json["place_id"] as String,
      userId: json["user_id"] as String,
      imageUrl: json["image_url"] as String,
      status: PlaceImageStatus.fromString((json["status"] as String?) ?? "pending"),
      createdAt: DateTime.parse(json["created_at"] as String),
      updatedAt: DateTime.parse(json["updated_at"] as String),
      userName: json["user_name"] as String?,
      userPhotoUrl: json["user_photo_url"] as String?,
      reviewedBy: json["reviewed_by"] as String?,
      reviewedAt: json["reviewed_at"] != null
          ? DateTime.parse(json["reviewed_at"] as String)
          : null,
      reviewReason: json["review_reason"] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      "place_id": placeId,
      "image_url": imageUrl,
      "status": status.value,
    };
  }
}

