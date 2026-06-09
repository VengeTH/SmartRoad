/// * Database Service
/// * Provides a PostgreSQL-backed data layer for SmartRoad.
/// * Communicates with our self-hosted backend API (or runs in demo mode).
/// * 
/// * This replaces Supabase as the backend provider.
/// * The backend API is implemented in Phase 5.
/// * For now, everything works in demo mode with local/in-memory data.
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "../core/config/env.dart";
import "../models/smartroad_user.dart";
import "../models/user_profile.dart";
import "../models/hazard.dart";
import "../models/hazard_comment.dart";
import "../models/place_comment.dart";
import "../models/place_image.dart";

/// * Result from a database query
class DbResult {
  final List<Map<String, dynamic>> rows;
  final int? count;
  final String? error;

  const DbResult({this.rows = const [], this.count, this.error});

  bool get isError => error != null;
  bool get isEmpty => rows.isEmpty;
  int get length => rows.length;
}

/// * Database service singleton
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;

  /// * Backend API URL (configured via env or default)
  String get _apiBaseUrl => Env.apiBaseUrl;

  /// * Whether we have a connection to the backend
  bool get isConnected => _isInitialized && Env.hasApiConfig;

  /// * Initialize the database service
  Future<void> initialize() async {
    if (Env.hasApiConfig) {
      try {
        final response = await http
            .get(Uri.parse("$_apiBaseUrl/health"))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _isInitialized = true;
          debugPrint("✅ DatabaseService connected to backend at $_apiBaseUrl");
          return;
        }
      } catch (e) {
        debugPrint("⚠️ DatabaseService: backend unreachable ($e)");
      }
    }
    _isInitialized = false;
    debugPrint("⚠️ DatabaseService: running in demo/local mode");
  }

  // ========================================================================
  // * RAW QUERY EXECUTION (sent to backend API)
  // ========================================================================

  /// * Execute a SQL query via the backend API.
  Future<DbResult> query(String sql, [List<dynamic>? params]) async {
    if (!isConnected) {
      return const DbResult(error: "Database not connected");
    }
    try {
      final response = await http.post(
        Uri.parse("$_apiBaseUrl/query"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"sql": sql, "params": params ?? []}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DbResult(
          rows: List<Map<String, dynamic>>.from(data['rows'] ?? []),
          count: data['count'] as int?,
        );
      }
      return DbResult(error: "API error: ${response.statusCode}");
    } catch (e) {
      return DbResult(error: "Query failed: $e");
    }
  }

  // ========================================================================
  // * AUTHENTICATION
  // ========================================================================

  /// * Sign up a new user
  Future<SmartRoadUser?> signUp(String email, String password, String name) async {
    if (isConnected) {
      try {
        final response = await http.post(
          Uri.parse("$_apiBaseUrl/auth/signup"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
            "name": name,
          }),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return SmartRoadUser.fromJson(data['user']);
        }
      } catch (e) {
        debugPrint("Signup error: $e");
      }
    }
    throw Exception("Sign up not available — backend not connected");
  }

  /// * Sign in an existing user
  Future<SmartRoadUser?> signIn(String email, String password) async {
    if (isConnected) {
      try {
        final response = await http.post(
          Uri.parse("$_apiBaseUrl/auth/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email, "password": password}),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return SmartRoadUser.fromJson(data['user']);
        }
      } catch (e) {
        debugPrint("Login error: $e");
      }
    }
    throw Exception("Sign in not available — backend not connected");
  }

  /// * Sign out the current user
  Future<void> signOut() async {
    if (isConnected) {
      try {
        await http.post(
          Uri.parse("$_apiBaseUrl/auth/logout"),
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("Logout error: $e");
      }
    }
  }

  // ========================================================================
  // * PROFILES
  // ========================================================================

  Future<UserProfile?> getProfile(String userId) async {
    if (isConnected) {
      final result = await query(
        "SELECT * FROM SmartRoad.profiles WHERE id = @id",
        [userId],
      );
      if (!result.isError && result.isNotEmpty) {
        return UserProfile.fromJson(result.rows.first);
      }
    }
    return null;
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    if (isConnected) {
      final sets = updates.entries
          .map((e) => "${e.key} = @${e.key}")
          .join(", ");
      await query(
        "UPDATE SmartRoad.profiles SET $sets, updated_at = NOW() WHERE id = @id",
        [userId, ...updates.values],
      );
    }
  }

  // ========================================================================
  // * HAZARDS
  // ========================================================================

  Future<List<Hazard>> getHazards() async {
    if (isConnected) {
      final result = await query(
        "SELECT * FROM SmartRoad.hazards ORDER BY created_at DESC LIMIT 100",
      );
      if (!result.isError) {
        return result.rows.map((json) => Hazard.fromJson(json)).toList();
      }
    }
    return [];
  }

  Future<void> createHazard(Map<String, dynamic> data) async {
    if (isConnected) {
      await query(
        """INSERT INTO SmartRoad.hazards (user_id, type, description, severity, location, image_url)
           VALUES (@user_id, @type, @description, @severity, ST_SetSRID(ST_MakePoint(@lon, @lat), 4326), @image_url)""",
        [data['user_id'], data['type'], data['description'], data['severity'], data['lon'], data['lat'], data['image_url']],
      );
    }
  }

  // ========================================================================
  // * COMMENTS
  // ========================================================================

  Future<List<HazardComment>> getHazardComments(String hazardId) async {
    if (isConnected) {
      final result = await query(
        "SELECT * FROM SmartRoad.hazard_comments WHERE hazard_id = @id ORDER BY created_at ASC",
        [hazardId],
      );
      if (!result.isError) {
        return result.rows.map((json) => HazardComment.fromJson(json)).toList();
      }
    }
    return [];
  }

  // ========================================================================
  // * IMAGE UPLOAD (stored as base64 in DB or file path)
  // ========================================================================

  Future<String?> uploadImage(dynamic imageFile, String fileName) async {
    // * Image upload requires the backend API to handle file storage.
    // * For now, return null (demo mode handles this locally).
    if (isConnected) {
      try {
        final request = http.MultipartRequest(
          "POST",
          Uri.parse("$_apiBaseUrl/upload"),
        );
        request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));
        final response = await request.send();
        if (response.statusCode == 200) {
          final data = jsonDecode(await response.stream.bytesToString());
          return data['url'] as String?;
        }
      } catch (e) {
        debugPrint("Upload error: $e");
      }
    }
    return null;
  }

  /// * Current user ID (for services that need it)
  String? get currentUserId => null; // * Managed by auth provider
}
