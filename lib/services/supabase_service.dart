import "package:supabase_flutter/supabase_flutter.dart";
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
  
  SupabaseClient get client => Supabase.instance.client;
  
  /// * Initialize Supabase
  Future<void> initialize() async {
    if (!Env.validate()) {
      throw Exception("Missing required environment variables");
    }
    
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }
  
  // * Authentication Methods
  
  /// * Sign up with email and password
  Future<AuthResponse> signUp(String email, String password, String name) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    return response;
  }
  
  /// * Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// * Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  /// * Get current user
  User? get currentUser => client.auth.currentUser;
  
  /// * Get current user ID
  String? get currentUserId => client.auth.currentUser?.id;
  
  /// * Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
  
  // * Profile Methods
  
  /// * Get user profile
  Future<UserProfile?> getProfile(String userId) async {
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }
  
  /// * Update user profile
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await client
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
    final response = await client
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
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to create hazards");
    }
    
    final hazardData = {
      'type': type.value,
      'description': description.trim(),
      'severity': severity.value,
      'location': 'POINT($longitude $latitude)',
      if (imageUrl != null) 'image_url': imageUrl,
      if (stickerFlag != null) 'sticker_flag': stickerFlag,
    };
    
    final response = await client
        .from('hazards')
        .insert(hazardData)
        .select()
        .single();
    
    return Hazard.fromJson(response as Map<String, dynamic>);
  }
  
  /// * Subscribe to realtime hazards updates
  RealtimeChannel subscribeToHazards({
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    final channel = client.channel('hazards_channel');
    
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
    final bytes = await file.readAsBytes();
    final uint8List = Uint8List.fromList(bytes);
    await client.storage
        .from(AppConstants.storageBucketName)
        .uploadBinary(fileName, uint8List);
    
    // * Get public URL
    final url = client.storage
        .from(AppConstants.storageBucketName)
        .getPublicUrl(fileName);
    
    return url;
  }
  
  /// * Upload image file bytes
  Future<String> uploadImageBytes(Uint8List bytes, String fileName) async {
    await client.storage
        .from(AppConstants.storageBucketName)
        .uploadBinary(fileName, bytes);
    
    final url = client.storage
        .from(AppConstants.storageBucketName)
        .getPublicUrl(fileName);
    
    return url;
  }
}

