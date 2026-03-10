import "package:supabase_flutter/supabase_flutter.dart";
import "package:flutter/foundation.dart";
import "dart:io";
import "dart:typed_data";
import "../models/hazard.dart";
import "../models/user_profile.dart";
import "../models/hazard_comment.dart";
import "../models/place_comment.dart";
import "../models/place_image.dart";
import "../core/config/env.dart";
import "../core/constants/app_constants.dart";

/// * Supabase service for database operations
class SupabaseService {
  static const String demoUserId = "demo-user-id";

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  bool _isDemoAuthenticated = false;

  final Map<String, List<PlaceComment>> _demoPlaceComments = {};
  final Map<String, Set<String>> _demoPlaceLikes = {};
  final Map<String, Map<String, int>> _demoPlaceRatings = {};
  final Map<String, List<PlaceImage>> _demoPlaceImages = {};

  /// * Check if running in demo mode (no database connection)
  bool get isDemoMode => !_isInitialized || !Env.validate();

  /// * Get Supabase client (returns null in demo mode)
  SupabaseClient? get client {
    if (isDemoMode || !_isInitialized) {
      return null;
    }
    try {
      return Supabase.instance.client;
    } catch (e) {
      // * Supabase not initialized
      return null;
    }
  }

  /// * Initialize Supabase (optional - can skip in demo mode)
  Future<void> initialize() async {
    if (!Env.validate()) {
      // * Demo mode - skip initialization
      debugPrint(
        "⚠️ Demo mode: Supabase not initialized (missing environment variables)",
      );
      _isInitialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint("✅ Supabase initialized successfully");
    } catch (e) {
      debugPrint("⚠️ Failed to initialize Supabase: $e");
      _isInitialized = false;
      // * Don't throw - allow demo mode
    }
  }

  /// * Mark demo mode as authenticated.
  void markDemoAuthenticated() {
    _isDemoAuthenticated = true;
  }

  /// * Mark demo mode as guest/not authenticated.
  void clearDemoAuthentication() {
    _isDemoAuthenticated = false;
  }

  // * Authentication Methods

  /// * Sign up with email and password
  Future<AuthResponse> signUp(
    String email,
    String password,
    String name,
  ) async {
    if (isDemoMode) {
      throw Exception("Sign up not available in demo mode");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    final response = await c.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    return response;
  }

  /// * Sign in with email and password
  /// * In demo mode, validates demo credentials and marks the local demo session.
  Future<AuthResponse> signIn(String email, String password) async {
    if (isDemoMode) {
      // * Check if using demo credentials
      if (email == AppConstants.demoEmail &&
          password == AppConstants.demoPassword) {
        _isDemoAuthenticated = true;
        debugPrint("✅ Demo login successful");
        // * Return a mock AuthResponse - the app will handle demo mode separately
        throw Exception(
          "DEMO_MODE_LOGIN",
        ); // * Special exception to indicate demo login
      } else {
        throw Exception(
          "Invalid credentials. Use demo credentials in demo mode.",
        );
      }
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    return await c.auth.signInWithPassword(email: email, password: password);
  }

  /// * Sign out
  /// * In demo mode, clears the local demo auth state.
  Future<void> signOut() async {
    if (isDemoMode) {
      _isDemoAuthenticated = false;
      return;
    }
    final c = client;
    if (c == null) {
      return;
    }
    await c.auth.signOut();
  }

  /// * Get current user (returns null when no authenticated session exists)
  User? get currentUser {
    if (isDemoMode) {
      if (!_isDemoAuthenticated) return null;
      return User(
        id: demoUserId,
        appMetadata: const {},
        userMetadata: const {
          "name": "Demo User",
          "email": AppConstants.demoEmail,
        },
        aud: "authenticated",
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    final c = client;
    return c?.auth.currentUser;
  }

  /// * Get current user ID
  String? get currentUserId {
    if (isDemoMode) {
      return _isDemoAuthenticated ? demoUserId : null;
    }
    return currentUser?.id;
  }

  /// * Check if user is authenticated
  bool get isAuthenticated {
    if (isDemoMode) {
      return _isDemoAuthenticated;
    }
    return currentUser != null;
  }

  String? get _effectiveUserId => currentUserId;

  // * Profile Methods

  /// * Get user profile
  Future<UserProfile?> getProfile(String userId) async {
    if (isDemoMode) {
      // * Return demo profile
      return UserProfile(
        id: userId,
        name: "Demo User",
        email: "demo@smartroad.app",
        photoUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterLevel: ReporterLevel.novice,
        validReportsCount: 0,
      );
    }
    final c = client;
    if (c == null) {
      return null;
    }
    final response =
        await c.from('profiles').select().eq('id', userId).maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  /// * Update user profile
  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    if (isDemoMode) {
      return; // * No-op in demo mode
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    await c.from('profiles').update(updates).eq('id', userId);
  }

  // * Hazard Methods

  /// * Get all hazards (with pagination)
  Future<List<Hazard>> getHazards({
    int limit = AppConstants.feedPageSize,
    int offset = 0,
  }) async {
    if (isDemoMode) {
      return []; // * Return empty list in demo mode
    }
    final c = client;
    if (c == null) {
      return [];
    }
    final response = await c
        .from('hazards')
        .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final List<Hazard> hazards = [];
    for (final item in response as List) {
      final hazardData = item as Map<String, dynamic>;
      final profileData = hazardData['profiles'] as Map<String, dynamic>?;

      if (profileData != null) {
        hazardData['user_name'] = profileData['name'];
        hazardData['user_photo_url'] = profileData['photo_url'];
      }

      hazards.add(Hazard.fromJson(hazardData));
    }

    return hazards;
  }

  /// * Get hazards within bounding box (for map)
  /// * Note: This requires a PostGIS function in Supabase
  /// * For now, we'll fetch all and filter client-side (not ideal for production)
  Future<List<Hazard>> getHazardsInBounds(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) async {
    if (isDemoMode) {
      return []; // * Return empty list in demo mode
    }
    // * Fetch all hazards (limited) and filter client-side
    // * In production, use PostGIS RPC function
    final allHazards = await getHazards(limit: AppConstants.maxMapMarkers);

    return allHazards.where((hazard) {
      return hazard.latitude >= minLat &&
          hazard.latitude <= maxLat &&
          hazard.longitude >= minLon &&
          hazard.longitude <= maxLon;
    }).toList();
  }

  /// * Create a new hazard
  Future<Hazard> createHazard({
    required HazardType type,
    required String description,
    required SeverityLevel severity,
    required double latitude,
    required double longitude,
    String? imageUrl,
    String? stickerFlag,
  }) async {
    if (isDemoMode) {
      throw Exception("Creating hazards not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to create hazards");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final hazardData = {
      'type': type.value,
      'description': description.trim(),
      'severity': severity.value,
      'location': 'POINT($longitude $latitude)',
      if (imageUrl != null) 'image_url': imageUrl,
      if (stickerFlag != null) 'sticker_flag': stickerFlag,
    };

    final response =
        await c.from('hazards').insert(hazardData).select().single();

    return Hazard.fromJson(response);
  }

  /// * Subscribe to realtime hazards updates
  RealtimeChannel? subscribeToHazards({
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    if (isDemoMode) {
      return null; // * No realtime in demo mode
    }
    final c = client;
    if (c == null) {
      return null;
    }
    final channel = c.channel('hazards_channel');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'hazards',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'hazards',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'hazards',
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();

    return channel;
  }

  // * Storage Methods

  /// * Upload image to Supabase Storage
  Future<String> uploadImage(File file, String fileName) async {
    if (isDemoMode) {
      // * Return a placeholder URL in demo mode
      return "demo://$fileName";
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    final bytes = await file.readAsBytes();
    await c.storage
        .from(AppConstants.storageBucketName)
        .uploadBinary(fileName, bytes);

    // * Get public URL
    final url = c.storage
        .from(AppConstants.storageBucketName)
        .getPublicUrl(fileName);

    return url;
  }

  /// * Upload image file bytes
  Future<String> uploadImageBytes(List<int> bytes, String fileName) async {
    if (isDemoMode) {
      // * Return a placeholder URL in demo mode
      return "demo://$fileName";
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    final uint8Bytes = Uint8List.fromList(bytes);
    await c.storage
        .from(AppConstants.storageBucketName)
        .uploadBinary(fileName, uint8Bytes);

    final url = c.storage
        .from(AppConstants.storageBucketName)
        .getPublicUrl(fileName);

    return url;
  }

  // * Comment Methods

  /// * Get comments for a hazard
  Future<List<HazardComment>> getHazardComments(String hazardId) async {
    if (isDemoMode) {
      return []; // * Return empty list in demo mode
    }
    final c = client;
    if (c == null) {
      return [];
    }
    final response = await c
        .from('hazard_comments')
        .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
        .eq('hazard_id', hazardId)
        .order('created_at', ascending: false);

    final List<HazardComment> comments = [];
    for (final item in response) {
      final Map<String, dynamic> commentData = item;
      final profileData = commentData['profiles'] as Map<String, dynamic>?;

      if (profileData != null) {
        commentData['user_name'] = profileData['name'];
        commentData['user_photo_url'] = profileData['photo_url'];
      }

      comments.add(HazardComment.fromJson(commentData));
    }

    return comments;
  }

  /// * Create a new comment on a hazard
  Future<HazardComment> createComment({
    required String hazardId,
    required String text,
  }) async {
    if (isDemoMode) {
      throw Exception("Creating comments not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to create comments");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final commentData = {'hazard_id': hazardId, 'text': text.trim()};

    final response =
        await c.from('hazard_comments').insert(commentData).select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''').single();

    final Map<String, dynamic> commentJson = response;
    final profileData = commentJson['profiles'] as Map<String, dynamic>?;

    if (profileData != null) {
      commentJson['user_name'] = profileData['name'];
      commentJson['user_photo_url'] = profileData['photo_url'];
    }

    return HazardComment.fromJson(commentJson);
  }

  /// * Update a comment
  Future<HazardComment> updateComment({
    required String commentId,
    required String text,
  }) async {
    if (isDemoMode) {
      throw Exception("Updating comments not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to update comments");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final response =
        await c
            .from('hazard_comments')
            .update({'text': text.trim()})
            .eq('id', commentId)
            .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
            .single();

    final commentJson = response;
    final profileData = commentJson['profiles'] as Map<String, dynamic>?;

    if (profileData != null) {
      commentJson['user_name'] = profileData['name'];
      commentJson['user_photo_url'] = profileData['photo_url'];
    }

    return HazardComment.fromJson(commentJson);
  }

  /// * Delete a comment
  Future<void> deleteComment(String commentId) async {
    if (isDemoMode) {
      throw Exception("Deleting comments not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to delete comments");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    await c.from('hazard_comments').delete().eq('id', commentId);
  }

  /// * Subscribe to realtime comments updates for a hazard
  RealtimeChannel? subscribeToComments({
    required String hazardId,
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    if (isDemoMode) {
      return null; // * No realtime in demo mode
    }
    final c = client;
    if (c == null) {
      return null;
    }
    final channel = c.channel('comments_channel_$hazardId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'hazard_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'hazard_id',
            value: hazardId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'hazard_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'hazard_id',
            value: hazardId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'hazard_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'hazard_id',
            value: hazardId,
          ),
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();

    return channel;
  }

  // * Place Preview (Known Locations) - Photos, Comments, Likes
  // *
  // * Expected tables in Supabase:
  // * - place_comments
  // * - place_images
  // * - place_likes
  // *
  // * See `supabase_places_schema.sql` for the recommended schema + RLS policies.

  /// * Get comments for a place
  Future<List<PlaceComment>> getPlaceComments(String placeId) async {
    if (isDemoMode) {
      final comments = List<PlaceComment>.from(
        _demoPlaceComments[placeId] ?? const [],
      );
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    }
    final c = client;
    if (c == null) {
      return [];
    }

    final response = await c
        .from('place_comments')
        .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
        .eq('place_id', placeId)
        .order('created_at', ascending: false);

    final comments = <PlaceComment>[];
    for (final item in response) {
      final Map<String, dynamic> commentData = item;
      final profileData = commentData['profiles'] as Map<String, dynamic>?;

      if (profileData != null) {
        commentData['user_name'] = profileData['name'];
        commentData['user_photo_url'] = profileData['photo_url'];
      }

      comments.add(PlaceComment.fromJson(commentData));
    }
    return comments;
  }

  /// * Create a new comment on a place
  Future<PlaceComment> createPlaceComment({
    required String placeId,
    required String text,
  }) async {
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to comment");
    }

    if (isDemoMode) {
      final now = DateTime.now();
      final userId = _effectiveUserId ?? demoUserId;
      final comment = PlaceComment(
        id: "demo-comment-${now.microsecondsSinceEpoch}",
        placeId: placeId,
        userId: userId,
        text: text.trim(),
        createdAt: now,
        updatedAt: now,
        userName: "Demo User",
      );
      final comments = _demoPlaceComments.putIfAbsent(
        placeId,
        () => <PlaceComment>[],
      );
      comments.insert(0, comment);
      return comment;
    }

    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final commentData = {'place_id': placeId, 'text': text.trim()};

    final response =
        await c.from('place_comments').insert(commentData).select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''').single();

    final Map<String, dynamic> commentJson = response;
    final profileData = commentJson['profiles'] as Map<String, dynamic>?;

    if (profileData != null) {
      commentJson['user_name'] = profileData['name'];
      commentJson['user_photo_url'] = profileData['photo_url'];
    }

    return PlaceComment.fromJson(commentJson);
  }

  /// * Update a place comment
  Future<PlaceComment> updatePlaceComment({
    required String commentId,
    required String text,
  }) async {
    if (isDemoMode) {
      throw Exception("Updating place comments not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to update comments");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final response =
        await c
            .from('place_comments')
            .update({'text': text.trim()})
            .eq('id', commentId)
            .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
            .single();

    final Map<String, dynamic> commentJson = response;
    final profileData = commentJson['profiles'] as Map<String, dynamic>?;

    if (profileData != null) {
      commentJson['user_name'] = profileData['name'];
      commentJson['user_photo_url'] = profileData['photo_url'];
    }

    return PlaceComment.fromJson(commentJson);
  }

  /// * Delete a place comment
  Future<void> deletePlaceComment(String commentId) async {
    if (isDemoMode) {
      throw Exception("Deleting place comments not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to delete comments");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    await c.from('place_comments').delete().eq('id', commentId);
  }

  /// * Subscribe to realtime comments updates for a place
  RealtimeChannel? subscribeToPlaceComments({
    required String placeId,
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    if (isDemoMode) {
      return null;
    }
    final c = client;
    if (c == null) {
      return null;
    }

    final channel = c.channel('place_comments_channel_$placeId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'place_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'place_id',
            value: placeId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'place_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'place_id',
            value: placeId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'place_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'place_id',
            value: placeId,
          ),
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();

    return channel;
  }

  /// * Get images for a place (optionally filtered by [status])
  Future<List<PlaceImage>> getPlaceImages({
    required String placeId,
    PlaceImageStatus? status,
  }) async {
    if (isDemoMode) {
      final source = List<PlaceImage>.from(
        _demoPlaceImages[placeId] ?? const [],
      );
      if (status == null) {
        source.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return source;
      }
      final filtered = source.where((item) => item.status == status).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    }
    final c = client;
    if (c == null) {
      return [];
    }

    var query = c
        .from('place_images')
        .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
        .eq('place_id', placeId);

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final response = await query.order('created_at', ascending: false);

    final images = <PlaceImage>[];
    for (final item in response) {
      final Map<String, dynamic> imageData = item;
      final profileData = imageData['profiles'] as Map<String, dynamic>?;

      if (profileData != null) {
        imageData['user_name'] = profileData['name'];
        imageData['user_photo_url'] = profileData['photo_url'];
      }

      images.add(PlaceImage.fromJson(imageData));
    }

    return images;
  }

  /// * Create a new place image record (defaults to pending)
  Future<PlaceImage> createPlaceImage({
    required String placeId,
    required String imageUrl,
  }) async {
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to submit photos");
    }

    if (isDemoMode) {
      final now = DateTime.now();
      final userId = _effectiveUserId ?? demoUserId;
      final image = PlaceImage(
        id: "demo-image-${now.microsecondsSinceEpoch}",
        placeId: placeId,
        userId: userId,
        imageUrl: imageUrl,
        status: PlaceImageStatus.approved,
        createdAt: now,
        updatedAt: now,
        userName: "Demo User",
      );
      final images = _demoPlaceImages.putIfAbsent(
        placeId,
        () => <PlaceImage>[],
      );
      images.insert(0, image);
      return image;
    }

    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final record = {
      'place_id': placeId,
      'image_url': imageUrl,
      'status': PlaceImageStatus.pending.value,
    };

    final response =
        await c.from('place_images').insert(record).select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''').single();

    final Map<String, dynamic> imageJson = response;
    final profileData = imageJson['profiles'] as Map<String, dynamic>?;

    if (profileData != null) {
      imageJson['user_name'] = profileData['name'];
      imageJson['user_photo_url'] = profileData['photo_url'];
    }

    return PlaceImage.fromJson(imageJson);
  }

  /// * Get pending images (admin moderation queue)
  Future<List<PlaceImage>> getPendingPlaceImages() async {
    if (isDemoMode) {
      return [];
    }
    final c = client;
    if (c == null) {
      return [];
    }

    final response = await c
        .from('place_images')
        .select('''
          *,
          profiles:user_id (
            name,
            photo_url
          )
        ''')
        .eq('status', PlaceImageStatus.pending.value)
        .order('created_at', ascending: true);

    final images = <PlaceImage>[];
    for (final item in response) {
      final Map<String, dynamic> imageData = item;
      final profileData = imageData['profiles'] as Map<String, dynamic>?;

      if (profileData != null) {
        imageData['user_name'] = profileData['name'];
        imageData['user_photo_url'] = profileData['photo_url'];
      }

      images.add(PlaceImage.fromJson(imageData));
    }

    return images;
  }

  /// * Approve a place image (admin)
  Future<void> approvePlaceImage(String imageId) async {
    if (isDemoMode) {
      throw Exception("Moderation not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to review photos");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    await c
        .from('place_images')
        .update({
          'status': PlaceImageStatus.approved.value,
          'reviewed_by': currentUserId,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'review_reason': null,
        })
        .eq('id', imageId);
  }

  /// * Reject a place image (admin)
  Future<void> rejectPlaceImage(String imageId, {String? reason}) async {
    if (isDemoMode) {
      throw Exception("Moderation not available in demo mode");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to review photos");
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    await c
        .from('place_images')
        .update({
          'status': PlaceImageStatus.rejected.value,
          'reviewed_by': currentUserId,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'review_reason': reason?.trim(),
        })
        .eq('id', imageId);
  }

  /// * Get likes count for a place
  Future<int> getPlaceLikesCount(String placeId) async {
    if (isDemoMode) {
      return (_demoPlaceLikes[placeId] ?? const <String>{}).length;
    }
    final c = client;
    if (c == null) {
      return 0;
    }

    final response = await c
        .from('place_likes')
        .select('user_id')
        .eq('place_id', placeId);

    return (response as List).length;
  }

  /// * Check if current user liked a place
  Future<bool> hasLikedPlace(String placeId) async {
    if (!isAuthenticated) {
      return false;
    }

    if (isDemoMode) {
      final userId = _effectiveUserId;
      if (userId == null) return false;
      return (_demoPlaceLikes[placeId] ?? const <String>{}).contains(userId);
    }

    final c = client;
    if (c == null) {
      return false;
    }

    final userId = currentUserId;
    if (userId == null) {
      return false;
    }

    final existing =
        await c
            .from('place_likes')
            .select('place_id')
            .eq('place_id', placeId)
            .eq('user_id', userId)
            .maybeSingle();

    return existing != null;
  }

  /// * Toggle like for current user on a place (like/unlike)
  Future<void> togglePlaceLike(String placeId) async {
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to like");
    }

    if (isDemoMode) {
      final userId = _effectiveUserId;
      if (userId == null) {
        throw Exception("User not available");
      }
      final likes = _demoPlaceLikes.putIfAbsent(placeId, () => <String>{});
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      return;
    }

    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final userId = currentUserId;
    if (userId == null) {
      throw Exception("User not available");
    }

    final existing =
        await c
            .from('place_likes')
            .select('place_id')
            .eq('place_id', placeId)
            .eq('user_id', userId)
            .maybeSingle();

    if (existing != null) {
      await c
          .from('place_likes')
          .delete()
          .eq('place_id', placeId)
          .eq('user_id', userId);
      return;
    }

    await c.from('place_likes').insert({
      'place_id': placeId,
      'user_id': userId,
    });
  }

  /// * Get current user's rating for a place (1–5), or null if not rated.
  Future<int?> getMyPlaceRating(String placeId) async {
    if (!isAuthenticated) {
      return null;
    }

    if (isDemoMode) {
      final userId = _effectiveUserId;
      if (userId == null) return null;
      return _demoPlaceRatings[placeId]?[userId];
    }

    final c = client;
    if (c == null) {
      return null;
    }
    final userId = currentUserId;
    if (userId == null) {
      return null;
    }

    final existing =
        await c
            .from('place_ratings')
            .select('rating')
            .eq('place_id', placeId)
            .eq('user_id', userId)
            .maybeSingle();

    if (existing == null) {
      return null;
    }

    final ratingValue = existing['rating'];
    if (ratingValue is int) {
      return ratingValue;
    }
    if (ratingValue is num) {
      return ratingValue.toInt();
    }
    return null;
  }

  /// * Get ratings summary for a place.
  /// *
  /// * Returns:
  /// * - avgRating: 0..5
  /// * - ratingsCount: 0..n
  Future<Map<String, dynamic>> getPlaceRatingsSummary(String placeId) async {
    if (isDemoMode) {
      final ratings =
          (_demoPlaceRatings[placeId] ?? const <String, int>{}).values.toList();
      if (ratings.isEmpty) {
        return {"avgRating": 0.0, "ratingsCount": 0};
      }

      final total = ratings.fold<int>(0, (sum, r) => sum + r);
      final avg = total / ratings.length;
      return {"avgRating": avg, "ratingsCount": ratings.length};
    }
    final c = client;
    if (c == null) {
      return {"avgRating": 0.0, "ratingsCount": 0};
    }

    final rows = await c
        .from('place_ratings')
        .select('rating')
        .eq('place_id', placeId);

    final ratings = <int>[];
    for (final row in rows) {
      final Map<String, dynamic> item = row;
      final value = item['rating'];
      if (value is int) {
        ratings.add(value);
        continue;
      }
      if (value is num) {
        ratings.add(value.toInt());
      }
    }

    if (ratings.isEmpty) {
      return {"avgRating": 0.0, "ratingsCount": 0};
    }

    final total = ratings.fold<int>(0, (sum, r) => sum + r);
    final avg = total / ratings.length;

    return {"avgRating": avg, "ratingsCount": ratings.length};
  }

  /// * Create or update the current user's rating for a place (1–5).
  Future<void> setPlaceRating({
    required String placeId,
    required int rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception("Rating must be between 1 and 5");
    }
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to rate places");
    }

    if (isDemoMode) {
      final userId = _effectiveUserId;
      if (userId == null) {
        throw Exception("User not available");
      }
      final ratings = _demoPlaceRatings.putIfAbsent(
        placeId,
        () => <String, int>{},
      );
      ratings[userId] = rating;
      return;
    }

    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }

    final userId = currentUserId;
    if (userId == null) {
      throw Exception("User not available");
    }

    final existing =
        await c
            .from('place_ratings')
            .select('rating')
            .eq('place_id', placeId)
            .eq('user_id', userId)
            .maybeSingle();

    if (existing != null) {
      await c
          .from('place_ratings')
          .update({'rating': rating})
          .eq('place_id', placeId)
          .eq('user_id', userId);
      return;
    }

    await c.from('place_ratings').insert({
      'place_id': placeId,
      'user_id': userId,
      'rating': rating,
    });
  }
}
