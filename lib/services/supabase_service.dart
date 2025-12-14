import "package:supabase_flutter/supabase_flutter.dart";
import "package:flutter/foundation.dart";
import "dart:io";
import "dart:typed_data";
import "../models/hazard.dart";
import "../models/user_profile.dart";
import "../core/config/env.dart";
import "../core/constants/app_constants.dart";

/// * Supabase service for database operations
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();
  
  bool _isInitialized = false;
  
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
      debugPrint("⚠️ Demo mode: Supabase not initialized (missing environment variables)");
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
  
  // * Authentication Methods
  
  /// * Sign up with email and password
  Future<AuthResponse> signUp(String email, String password, String name) async {
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
  /// * In demo mode, validates demo credentials and returns a mock response
  Future<AuthResponse> signIn(String email, String password) async {
    if (isDemoMode) {
      // * Check if using demo credentials
      if (email == AppConstants.demoEmail && password == AppConstants.demoPassword) {
        // * Create a mock user for demo mode
        // * Note: This won't actually authenticate with Supabase, but allows demo flow
        debugPrint("✅ Demo login successful");
        // * Return a mock AuthResponse - the app will handle demo mode separately
        throw Exception("DEMO_MODE_LOGIN"); // * Special exception to indicate demo login
      } else {
        throw Exception("Invalid credentials. Use demo credentials in demo mode.");
      }
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    return await c.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// * Sign out
  /// * In demo mode, clears the demo user state
  Future<void> signOut() async {
    if (isDemoMode) {
      // * Demo mode sign out is handled by clearing demo user state
      // * This is done in the UI layer (profile screen)
      return;
    }
    final c = client;
    if (c == null) {
      return;
    }
    await c.auth.signOut();
  }
  
  /// * Get current user (returns null in demo mode)
  User? get currentUser {
    final c = client;
    return c?.auth.currentUser;
  }
  
  /// * Get current user ID (returns null in demo mode)
  String? get currentUserId => currentUser?.id;
  
  /// * Check if user is authenticated
  bool get isAuthenticated {
    if (isDemoMode) return false;
    return currentUser != null;
  }
  
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
    final response = await c
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }
  
  /// * Update user profile
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    if (isDemoMode) {
      return; // * No-op in demo mode
    }
    final c = client;
    if (c == null) {
      throw Exception("Supabase client not available");
    }
    await c
        .from('profiles')
        .update(updates)
        .eq('id', userId);
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
    
    final response = await c
        .from('hazards')
        .insert(hazardData)
        .select()
        .single();
    
    return Hazard.fromJson(response as Map<String, dynamic>);
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
}

