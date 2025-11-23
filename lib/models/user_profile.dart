/// * User profile model
class UserProfile {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;
  final ReporterLevel reporterLevel;
  final int validReportsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  UserProfile({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
    required this.reporterLevel,
    required this.validReportsCount,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      reporterLevel: ReporterLevel.fromString(json['reporter_level'] as String),
      validReportsCount: (json['valid_reports_count'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }
  
  UserProfile copyWith({
    String? name,
    String? photoUrl,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      reporterLevel: reporterLevel,
      validReportsCount: validReportsCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// * Reporter level enum
enum ReporterLevel {
  novice('Novice'),
  verified('Verified'),
  expert('Expert'),
  admin('Admin');
  
  final String value;
  const ReporterLevel(this.value);
  
  static ReporterLevel fromString(String value) {
    return ReporterLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReporterLevel.novice,
    );
  }
}

