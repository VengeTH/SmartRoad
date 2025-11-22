import "../core/config/app_config.dart";
import "../models/user_model.dart";
import "auth_service.dart";
import "local_auth_service.dart";

/// * Authentication service adapter - switches between local and Supabase
class AuthServiceAdapter {
  AuthServiceAdapter._();

  static final AuthServiceAdapter instance = AuthServiceAdapter._();

  /// * Get current user ID
  Future<String?> getCurrentUserId() async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.getCurrentUserId();
    } else {
      return AuthService.instance.currentUserId;
    }
  }

  /// * Check if user is authenticated
  Future<bool> isAuthenticated() async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.isAuthenticated();
    } else {
      return AuthService.instance.isAuthenticated;
    }
  }

  /// * Sign up
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.signUp(
        email: email,
        password: password,
        name: name,
      );
    } else {
      return await AuthService.instance.signUp(
        email: email,
        password: password,
        name: name,
      );
    }
  }

  /// * Sign in
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.signIn(
        email: email,
        password: password,
      );
    } else {
      return await AuthService.instance.signIn(
        email: email,
        password: password,
      );
    }
  }

  /// * Sign out
  Future<void> signOut() async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.signOut();
    } else {
      return await AuthService.instance.signOut();
    }
  }

  /// * Get user profile
  Future<UserModel> getUserProfile(String userId) async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.getUserProfile(userId);
    } else {
      return await AuthService.instance.getUserProfile(userId);
    }
  }

  /// * Update profile
  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? profileImage,
  }) async {
    if (AppConfig.useLocalStorage) {
      return await LocalAuthService.instance.updateProfile(
        userId: userId,
        name: name,
        profileImage: profileImage,
      );
    } else {
      return await AuthService.instance.updateProfile(
        userId: userId,
        name: name,
        profileImage: profileImage,
      );
    }
  }
}

