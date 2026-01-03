/// * Comment model for hazards (similar to Waze comments)
class HazardComment {
  final String id;
  final String hazardId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // * Optional user info (from join)
  final String? userName;
  final String? userPhotoUrl;
  
  HazardComment({
    required this.id,
    required this.hazardId,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userPhotoUrl,
  });
  
  /// * Create HazardComment from Supabase JSON
  factory HazardComment.fromJson(Map<String, dynamic> json) {
    return HazardComment(
      id: json['id'] as String,
      hazardId: json['hazard_id'] as String,
      userId: json['user_id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userPhotoUrl: json['user_photo_url'] as String?,
    );
  }
  
  /// * Convert HazardComment to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'hazard_id': hazardId,
      'text': text.trim(),
    };
  }
}
