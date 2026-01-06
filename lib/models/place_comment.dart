/// * Comment model for places (Waze-style comments on known locations)
class PlaceComment {
  final String id;
  final String placeId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  // * Optional user info (from join)
  final String? userName;
  final String? userPhotoUrl;

  PlaceComment({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userPhotoUrl,
  });

  /// * Create PlaceComment from Supabase JSON
  factory PlaceComment.fromJson(Map<String, dynamic> json) {
    return PlaceComment(
      id: json["id"] as String,
      placeId: json["place_id"] as String,
      userId: json["user_id"] as String,
      text: json["text"] as String,
      createdAt: DateTime.parse(json["created_at"] as String),
      updatedAt: DateTime.parse(json["updated_at"] as String),
      userName: json["user_name"] as String?,
      userPhotoUrl: json["user_photo_url"] as String?,
    );
  }

  /// * Convert PlaceComment to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      "place_id": placeId,
      "text": text.trim(),
    };
  }
}

