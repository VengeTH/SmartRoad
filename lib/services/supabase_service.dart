/// * Data Service — SmartRoad's primary data access layer.
/// * Handles all database operations, authentication, and storage via PostgreSQL.
/// * Replaces the former Supabase-backed implementation with DatabaseService.
/// *
/// * Architecture:
/// *   Flutter App → SupabaseService (this) → DatabaseService → Backend API → PostgreSQL
/// *                                        → Demo mode (local/in-memory fallback)
import "package:flutter/foundation.dart";
import "dart:io";
import "dart:typed_data";
import "../models/smartroad_user.dart";
import "../models/hazard.dart";
import "../models/user_profile.dart";
import "../models/hazard_comment.dart";
import "../models/place_comment.dart";
import "../models/place_image.dart";
import "../core/config/env.dart";
import "../core/constants/app_constants.dart";
import "database_service.dart";

class SupabaseService {
  static const String demoUserId = SmartRoadUser.demoUserId;

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final DatabaseService _db = DatabaseService();
  bool _isDemoAuthenticated = false;

  final Map<String, List<PlaceComment>> _demoPlaceComments = {};
  final Map<String, Set<String>> _demoPlaceLikes = {};
  final Map<String, Map<String, int>> _demoPlaceRatings = {};
  final Map<String, List<PlaceImage>> _demoPlaceImages = {};

  bool get isDemoMode => !_db.isConnected;
  DatabaseService? get client => _db.isConnected ? _db : null;

  Future<void> initialize() async {
    await _db.initialize();
    if (_db.isConnected) {
      debugPrint("✅ SupabaseService: connected to PostgreSQL via backend");
    } else {
      debugPrint("⚠️ SupabaseService: running in demo mode");
    }
  }

  void markDemoAuthenticated() => _isDemoAuthenticated = true;
  void clearDemoAuthentication() => _isDemoAuthenticated = false;
  String? get _effectiveUserId => currentUserId;

  // AUTH
  Future<SmartRoadUser> signUp(String email, String password, String name) async {
    if (isDemoMode) throw Exception("Sign up not available in demo mode");
    final user = await _db.signUp(email, password, name);
    if (user == null) throw Exception("Sign up failed");
    return user;
  }

  Future<SmartRoadUser> signIn(String email, String password) async {
    if (isDemoMode) {
      if (email == AppConstants.demoEmail && password == AppConstants.demoPassword) {
        _isDemoAuthenticated = true;
        throw Exception("DEMO_MODE_LOGIN");
      }
      throw Exception("Invalid credentials");
    }
    final user = await _db.signIn(email, password);
    if (user == null) throw Exception("Sign in failed");
    return user;
  }

  Future<void> signOut() async {
    if (isDemoMode) { _isDemoAuthenticated = false; return; }
    await _db.signOut();
  }

  SmartRoadUser? get currentUser =>
    isDemoMode && _isDemoAuthenticated ? SmartRoadUser.createDemo() : null;

  String? get currentUserId => isDemoMode ? (_isDemoAuthenticated ? demoUserId : null) : null;
  bool get isAuthenticated => isDemoMode ? _isDemoAuthenticated : _db.isConnected;

  // PROFILES
  Future<UserProfile?> getProfile(String userId) async {
    if (isDemoMode) return UserProfile(
      id: userId, name: "Demo User", email: "demo@smartroad.app",
      photoUrl: null, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      reporterLevel: ReporterLevel.novice, validReportsCount: 0,
    );
    return await _db.getProfile(userId);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    if (isDemoMode) return;
    await _db.updateProfile(userId, updates);
  }

  // HAZARDS
  Future<List<Hazard>> getHazards({int limit = 20, int offset = 0}) async {
    if (isDemoMode) return [];
    return await _db.getHazards();
  }

  Future<List<Hazard>> getHazardsInBounds(double minLat, double minLon, double maxLat, double maxLon) async {
    if (isDemoMode || !_db.isConnected) return [];
    final r = await _db.query(
      "SELECT * FROM SmartRoad.hazards WHERE ST_Y(location::geometry) BETWEEN @1 AND @2 AND ST_X(location::geometry) BETWEEN @3 AND @4 ORDER BY created_at DESC",
      [minLat, maxLat, minLon, maxLon],
    );
    if (!r.isError) return r.rows.map((j) => Hazard.fromJson(j)).toList();
    return [];
  }

  Future<void> createHazard(Map<String, dynamic> data) async {
    if (isDemoMode) { debugPrint("⚠️ [Demo] Hazard saved locally"); return; }
    await _db.createHazard(data);
  }

  // HAZARD COMMENTS
  Future<List<HazardComment>> getHazardComments(String hazardId) async {
    if (isDemoMode) return [];
    return await _db.getHazardComments(hazardId);
  }

  Future<HazardComment> createComment({required String hazardId, required String text}) async {
    if (isDemoMode) throw Exception("Comments not available in demo mode");
    final userId = currentUserId;
    if (userId == null) throw Exception("Not authenticated");
    final r = await _db.query(
      "INSERT INTO SmartRoad.hazard_comments (hazard_id, user_id, text) VALUES (@1, @2, @3) RETURNING *",
      [hazardId, userId, text.trim()],
    );
    if (!r.isError && r.rows.isNotEmpty) return HazardComment.fromJson(r.rows.first);
    throw Exception("Failed to create comment");
  }

  Future<HazardComment> updateComment({required String commentId, required String text}) async {
    if (isDemoMode) throw Exception("Not available in demo mode");
    final r = await _db.query(
      "UPDATE SmartRoad.hazard_comments SET text = @1, updated_at = NOW() WHERE id = @2 RETURNING *",
      [text.trim(), commentId],
    );
    if (!r.isError && r.rows.isNotEmpty) return HazardComment.fromJson(r.rows.first);
    throw Exception("Failed to update comment");
  }

  Future<void> deleteComment(String commentId) async {
    if (isDemoMode) return;
    await _db.query("DELETE FROM SmartRoad.hazard_comments WHERE id = @1", [commentId]);
  }

  dynamic subscribeToComments({String? hazardId, void Function(Map<String, dynamic>)? onInsert, void Function(Map<String, dynamic>)? onUpdate, void Function(Map<String, dynamic>)? onDelete}) => null;
  dynamic subscribeToHazards({void Function(Map<String, dynamic>)? onInsert, void Function(Map<String, dynamic>)? onUpdate, void Function(Map<String, dynamic>)? onDelete}) => null;
  dynamic subscribeToPlaceComments({String? placeId, void Function(Map<String, dynamic>)? onInsert, void Function(Map<String, dynamic>)? onUpdate, void Function(Map<String, dynamic>)? onDelete}) => null;

  // PLACES
  Future<List<PlaceComment>> getPlaceComments(String placeId) async {
    if (isDemoMode) {
      final c = List<PlaceComment>.from(_demoPlaceComments[placeId] ?? []);
      c.sort((a, b) => b.createdAt.compareTo(a.createdAt)); return c;
    }
    if (!_db.isConnected) return [];
    final r = await _db.query("SELECT * FROM SmartRoad.place_comments WHERE place_id = @1 ORDER BY created_at DESC", [placeId]);
    if (!r.isError) return r.rows.map((j) => PlaceComment.fromJson(j)).toList();
    return [];
  }

  Future<PlaceComment> createPlaceComment({required String placeId, required String text}) async {
    if (isDemoMode) {
      final now = DateTime.now(); final uid = _effectiveUserId ?? demoUserId;
      final c = PlaceComment(id: "d-", placeId: placeId, userId: uid, text: text.trim(), createdAt: now, updatedAt: now, userName: "Demo User");
      _demoPlaceComments.putIfAbsent(placeId, () => []).insert(0, c); return c;
    }
    final uid = currentUserId; if (uid == null) throw Exception("Not authenticated");
    final r = await _db.query("INSERT INTO SmartRoad.place_comments (place_id, user_id, text) VALUES (@1, @2, @3) RETURNING *", [placeId, uid, text.trim()]);
    if (!r.isError && r.rows.isNotEmpty) return PlaceComment.fromJson(r.rows.first);
    throw Exception("Failed");
  }

  Future<PlaceComment> updatePlaceComment({required String commentId, required String text}) async {
    if (isDemoMode) throw Exception("Not available in demo mode");
    final r = await _db.query("UPDATE SmartRoad.place_comments SET text = @1, updated_at = NOW() WHERE id = @2 RETURNING *", [text.trim(), commentId]);
    if (!r.isError && r.rows.isNotEmpty) return PlaceComment.fromJson(r.rows.first);
    throw Exception("Failed");
  }

  Future<void> deletePlaceComment(String commentId) async {
    if (isDemoMode) return;
    await _db.query("DELETE FROM SmartRoad.place_comments WHERE id = @1", [commentId]);
  }

  Future<int> getPlaceLikesCount(String placeId) async {
    if (isDemoMode) return (_demoPlaceLikes[placeId] ?? <String>{}).length;
    if (!_db.isConnected) return 0;
    final r = await _db.query("SELECT COUNT(*) AS c FROM SmartRoad.place_likes WHERE place_id = @1", [placeId]);
    if (!r.isError && r.rows.isNotEmpty) return (r.rows.first['c'] as num?)?.toInt() ?? 0;
    return 0;
  }

  Future<bool> hasLikedPlace(String placeId) async {
    if (!isAuthenticated) return false;
    if (isDemoMode) { final u = _effectiveUserId; return u != null && (_demoPlaceLikes[placeId] ?? <String>{}).contains(u); }
    final uid = currentUserId; if (uid == null) return false;
    final r = await _db.query("SELECT 1 FROM SmartRoad.place_likes WHERE place_id = @1 AND user_id = @2", [placeId, uid]);
    return r.rows.isNotEmpty;
  }

  Future<void> togglePlaceLike(String placeId, {String? userId}) async {
    if (!isAuthenticated) throw Exception("Must be authenticated");
    final uid = userId ?? currentUserId; if (uid == null) throw Exception("User not available");
    if (isDemoMode) {
      final s = _demoPlaceLikes.putIfAbsent(placeId, () => <String>{});
      if (s.contains(uid)) s.remove(uid); else s.add(uid); return;
    }
    final e = await _db.query("SELECT 1 FROM SmartRoad.place_likes WHERE place_id = @1 AND user_id = @2", [placeId, uid]);
    if (e.rows.isNotEmpty) { await _db.query("DELETE FROM SmartRoad.place_likes WHERE place_id = @1 AND user_id = @2", [placeId, uid]); }
    else { await _db.query("INSERT INTO SmartRoad.place_likes (place_id, user_id) VALUES (@1, @2)", [placeId, uid]); }
  }

  Future<int?> getMyPlaceRating(String placeId) async {
    if (!isAuthenticated) return null;
    if (isDemoMode) { final u = _effectiveUserId; if (u == null) return null; final ratings = _demoPlaceRatings[placeId]; return ratings?[u]; }
    final uid = currentUserId; if (uid == null) return null;
    final r = await _db.query("SELECT rating FROM SmartRoad.place_ratings WHERE place_id = @1 AND user_id = @2", [placeId, uid]);
    if (!r.isError && r.rows.isNotEmpty) { final v = r.rows.first['rating']; if (v is int) return v; if (v is num) return v.toInt(); }
    return null;
  }

  Future<Map<String, dynamic>> getPlaceRatingsSummary(String placeId) async {
    if (isDemoMode) {
      final vals = (_demoPlaceRatings[placeId] ?? <String, int>{}).values.toList();
      if (vals.isEmpty) return {"avgRating": 0.0, "ratingsCount": 0};
      return {"avgRating": vals.fold<int>(0, (s, r) => s + r) / vals.length, "ratingsCount": vals.length};
    }
    if (!_db.isConnected) return {"avgRating": 0.0, "ratingsCount": 0};
    final r = await _db.query("SELECT AVG(rating) AS a, COUNT(*) AS c FROM SmartRoad.place_ratings WHERE place_id = @1", [placeId]);
    if (!r.isError && r.rows.isNotEmpty) return {"avgRating": (r.rows.first['a'] as num?)?.toDouble() ?? 0.0, "ratingsCount": (r.rows.first['c'] as num?)?.toInt() ?? 0};
    return {"avgRating": 0.0, "ratingsCount": 0};
  }

  Future<void> setPlaceRating({required String placeId, required int rating}) async {
    if (rating < 1 || rating > 5) throw Exception("Rating must be 1-5");
    if (!isAuthenticated) throw Exception("Must be authenticated");
    if (isDemoMode) { final u = _effectiveUserId; if (u != null) _demoPlaceRatings.putIfAbsent(placeId, () => <String, int>{})[u] = rating; return; }
    final uid = currentUserId; if (uid == null) throw Exception("User not available");
    await _db.query("INSERT INTO SmartRoad.place_ratings (place_id, user_id, rating) VALUES (@1, @2, @3) ON CONFLICT (place_id, user_id) DO UPDATE SET rating = @3, updated_at = NOW()", [placeId, uid, rating]);
  }

  // PLACE IMAGES
  Future<List<PlaceImage>> getPlaceImages({required String placeId, PlaceImageStatus? status}) async {
    if (isDemoMode) {
      var s = List<PlaceImage>.from(_demoPlaceImages[placeId] ?? []);
      if (status != null) s = s.where((i) => i.status == status).toList();
      s.sort((a, b) => b.createdAt.compareTo(a.createdAt)); return s;
    }
    if (!_db.isConnected) return [];
    var sql = "SELECT * FROM SmartRoad.place_images WHERE place_id = @1";
    if (status != null) sql += " AND status = ''";
    sql += " ORDER BY created_at DESC";
    final r = await _db.query(sql, [placeId]);
    if (!r.isError) return r.rows.map((j) => PlaceImage.fromJson(j)).toList();
    return [];
  }

  Future<PlaceImage> createPlaceImage({required String placeId, required String imageUrl}) async {
    if (isDemoMode) {
      final now = DateTime.now(); final uid = _effectiveUserId ?? demoUserId;
      final img = PlaceImage(id: "d-", placeId: placeId, userId: uid, imageUrl: imageUrl, status: PlaceImageStatus.approved, createdAt: now, updatedAt: now, userName: "Demo User");
      _demoPlaceImages.putIfAbsent(placeId, () => []).insert(0, img); return img;
    }
    final uid = currentUserId; if (uid == null) throw Exception("Not authenticated");
    final r = await _db.query("INSERT INTO SmartRoad.place_images (place_id, user_id, image_url, status) VALUES (@1, @2, @3, 'pending') RETURNING *", [placeId, uid, imageUrl]);
    if (!r.isError && r.rows.isNotEmpty) return PlaceImage.fromJson(r.rows.first);
    throw Exception("Failed");
  }

  Future<List<PlaceImage>> getPendingPlaceImages() async {
    if (isDemoMode || !_db.isConnected) return [];
    final r = await _db.query("SELECT * FROM SmartRoad.place_images WHERE status = 'pending' ORDER BY created_at DESC");
    if (!r.isError) return r.rows.map((j) => PlaceImage.fromJson(j)).toList();
    return [];
  }

  Future<void> approvePlaceImage(String imageId) async {
    if (isDemoMode) return;
    await _db.query("UPDATE SmartRoad.place_images SET status = 'approved', reviewed_at = NOW() WHERE id = @1", [imageId]);
  }

  Future<void> rejectPlaceImage(String imageId, {String? reason}) async {
    if (isDemoMode) return;
    await _db.query("UPDATE SmartRoad.place_images SET status = 'rejected', review_reason = @1, reviewed_at = NOW() WHERE id = @2", [reason, imageId]);
  }

  // IMAGE UPLOAD
  Future<String?> uploadImage(File imageFile, String fileName) async {
    if (isDemoMode) return null;
    return await _db.uploadImage(imageFile, fileName);
  }

  Future<String?> uploadImageBytes(Uint8List bytes, String fileName) async {
    if (isDemoMode) return null;
    try {
      final tmp = File('/');
      await tmp.writeAsBytes(bytes);
      final url = await _db.uploadImage(tmp, fileName);
      await tmp.delete(); return url;
    } catch (e) { debugPrint("Upload error: "); return null; }
  }

  // COMMUTE AI CACHE
  Future<Map<String, dynamic>?> getCommuteAiCache(String cacheKey) async {
    if (!_db.isConnected) return null;
    final r = await _db.query("SELECT payload FROM SmartRoad.commute_ai_cache WHERE cache_key = @1 AND expires_at > NOW()", [cacheKey]);
    if (!r.isError && r.rows.isNotEmpty) { final p = r.rows.first['payload']; if (p is Map<String, dynamic>) return p; }
    return null;
  }

  Future<void> upsertCommuteAiCache(String cacheKey, Map<String, dynamic> payload, {int ttlMinutes = 1440}) async {
    if (!_db.isConnected) return;
    await _db.query(
      "INSERT INTO SmartRoad.commute_ai_cache (cache_key, payload, expires_at) VALUES (@1, @2, NOW() + INTERVAL '1 day') "
      "ON CONFLICT (cache_key) DO UPDATE SET payload = @2, expires_at = NOW() + INTERVAL '1 day', hit_count = SmartRoad.commute_ai_cache.hit_count + 1",
      [cacheKey, payload],
    );
  }
}
