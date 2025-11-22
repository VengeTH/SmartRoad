import "package:supabase_flutter/supabase_flutter.dart";
import "../core/config/supabase_config.dart";
import "../models/user_model.dart";

/// * Authentication service for handling user authentication
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// * Get current user
  User? get currentUser => SupabaseConfig.client.auth.currentUser;

  /// * Get current user ID
  String? get currentUserId => currentUser?.id;

  /// * Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// * Sign up with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // * Create auth user
      final AuthResponse response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception("Failed to create user");
      }

      // * Create user profile
      final Map<String, dynamic> profileData = {
        "id": response.user!.id,
        "email": email,
        "name": name,
        "created_at": DateTime.now().toIso8601String(),
        "reporter_level": 1,
      };

      await SupabaseConfig.client
          .from("users")
          .insert(profileData)
          .select()
          .single();

      // * Fetch created profile
      final Map<String, dynamic> profile = await SupabaseConfig.client
          .from("users")
          .select()
          .eq("id", response.user!.id)
          .single();

      return UserModel.fromJson(profile);
    } catch (e) {
      throw Exception("Sign up failed: ${e.toString()}");
    }
  }

  /// * Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception("Invalid credentials");
      }

      // * Fetch user profile
      final Map<String, dynamic> profile = await SupabaseConfig.client
          .from("users")
          .select()
          .eq("id", response.user!.id)
          .single();

      return UserModel.fromJson(profile);
    } catch (e) {
      throw Exception("Sign in failed: ${e.toString()}");
    }
  }

  /// * Sign out
  Future<void> signOut() async {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (e) {
      throw Exception("Sign out failed: ${e.toString()}");
    }
  }

  /// * Get user profile
  Future<UserModel> getUserProfile(String userId) async {
    try {
      final Map<String, dynamic> profile = await SupabaseConfig.client
          .from("users")
          .select()
          .eq("id", userId)
          .single();

      return UserModel.fromJson(profile);
    } catch (e) {
      throw Exception("Failed to fetch user profile: ${e.toString()}");
    }
  }

  /// * Update user profile
  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? profileImage,
  }) async {
    try {
      final Map<String, dynamic> updates = <String, dynamic>{};

      if (name != null) {
        updates["name"] = name;
      }

      if (profileImage != null) {
        updates["profile_image"] = profileImage;
      }

      await SupabaseConfig.client
          .from("users")
          .update(updates)
          .eq("id", userId);

      return await getUserProfile(userId);
    } catch (e) {
      throw Exception("Failed to update profile: ${e.toString()}");
    }
  }
}

