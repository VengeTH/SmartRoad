/// * SmartRoad User model
/// * Replaces Supabase's built-in User type for our PostgreSQL-backed auth.
class SmartRoadUser {
  final String id;
  final String email;
  final String? name;
  final DateTime createdAt;
  final DateTime? lastSignInAt;

  const SmartRoadUser({
    required this.id,
    required this.email,
    this.name,
    required this.createdAt,
    this.lastSignInAt,
  });

  factory SmartRoadUser.fromJson(Map<String, dynamic> json) {
    return SmartRoadUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.tryParse(json['last_sign_in_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (name != null) 'name': name,
    'created_at': createdAt.toIso8601String(),
    if (lastSignInAt != null) 'last_sign_in_at': lastSignInAt!.toIso8601String(),
  };

  /// Demo user constant used in demo/guest mode.
  static const String demoUserId = 'demo-user-id';
  static const String demoEmail = 'demo@smartroad.app';

  static SmartRoadUser createDemo() => SmartRoadUser(
    id: demoUserId,
    email: demoEmail,
    name: 'Demo User',
    createdAt: DateTime.now(),
  );
}
