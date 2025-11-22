/// * User model representing a user in the system
class UserModel {
  final String id;
  final String email;
  final String? name;
  final DateTime createdAt;
  final String? profileImage;
  final int reporterLevel;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    required this.createdAt,
    this.profileImage,
    this.reporterLevel = 1,
  });

  /// * Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"] as String,
      email: json["email"] as String,
      name: json["name"] as String?,
      createdAt: DateTime.parse(json["created_at"] as String),
      profileImage: json["profile_image"] as String?,
      reporterLevel: json["reporter_level"] as int? ?? 1,
    );
  }

  /// * Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "name": name,
      "created_at": createdAt.toIso8601String(),
      "profile_image": profileImage,
      "reporter_level": reporterLevel,
    };
  }

  /// * Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    String? profileImage,
    int? reporterLevel,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      profileImage: profileImage ?? this.profileImage,
      reporterLevel: reporterLevel ?? this.reporterLevel,
    );
  }
}

