import "dart:convert";
import "../models/user_model.dart";
import "local_storage_service.dart";

/// * Local authentication service (no database required)
class LocalAuthService {
  LocalAuthService._();

  static final LocalAuthService instance = LocalAuthService._();
  static const String _currentUserKey = "current_user_id";
  static const String _usersFile = "users.json";

  /// * Get current user ID
  Future<String?> getCurrentUserId() async {
    return await LocalStorageService.instance.readString(_currentUserKey);
  }

  /// * Get current user
  Future<UserModel?> getCurrentUser() async {
    final String? userId = await getCurrentUserId();
    if (userId == null) return null;

    try {
      final List<Map<String, dynamic>> users =
          await LocalStorageService.instance.readJsonList(_usersFile);
      try {
        final Map<String, dynamic> userData =
            users.firstWhere((u) => u["id"] == userId);
        return UserModel.fromJson(userData);
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// * Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final String? userId = await getCurrentUserId();
    return userId != null;
  }

  /// * Sign up with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    // * Check if user already exists
    final List<Map<String, dynamic>> users =
        await LocalStorageService.instance.readJsonList(_usersFile);

    if (users.any((u) => u["email"] == email)) {
      throw Exception("User with this email already exists");
    }

    // * Create new user
    final String userId = DateTime.now().millisecondsSinceEpoch.toString();
    final Map<String, dynamic> userData = {
      "id": userId,
      "email": email,
      "name": name,
      "created_at": DateTime.now().toIso8601String(),
      "reporter_level": 1,
      "password_hash": _hashPassword(password), // * Simple hash for demo
    };

    users.add(userData);
    await LocalStorageService.instance.writeJsonList(_usersFile, users);

    // * Set as current user
    await LocalStorageService.instance.saveString(_currentUserKey, userId);

    return UserModel.fromJson(userData);
  }

  /// * Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final List<Map<String, dynamic>> users =
        await LocalStorageService.instance.readJsonList(_usersFile);

    try {
      final Map<String, dynamic> userData = users.firstWhere(
        (u) => u["email"] == email && u["password_hash"] == _hashPassword(password),
      );

      // * Set as current user
      await LocalStorageService.instance.saveString(_currentUserKey, userData["id"] as String);

      return UserModel.fromJson(userData);
    } catch (e) {
      throw Exception("Invalid email or password");
    }
  }

  /// * Sign out
  Future<void> signOut() async {
    await LocalStorageService.instance.remove(_currentUserKey);
  }

  /// * Get user profile
  Future<UserModel> getUserProfile(String userId) async {
    final List<Map<String, dynamic>> users =
        await LocalStorageService.instance.readJsonList(_usersFile);

    try {
      final Map<String, dynamic> userData =
          users.firstWhere((u) => u["id"] == userId);
      return UserModel.fromJson(userData);
    } catch (e) {
      throw Exception("User not found");
    }
  }

  /// * Update user profile
  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? profileImage,
  }) async {
    final List<Map<String, dynamic>> users =
        await LocalStorageService.instance.readJsonList(_usersFile);

    final int userIndex = users.indexWhere((u) => u["id"] == userId);
    if (userIndex == -1) {
      throw Exception("User not found");
    }

    if (name != null) {
      users[userIndex]["name"] = name;
    }
    if (profileImage != null) {
      users[userIndex]["profile_image"] = profileImage;
    }

    await LocalStorageService.instance.writeJsonList(_usersFile, users);
    return UserModel.fromJson(users[userIndex]);
  }

  /// * Simple password hash (for demo only - not secure!)
  String _hashPassword(String password) {
    return base64Encode(utf8.encode(password)).substring(0, 20);
  }
}

