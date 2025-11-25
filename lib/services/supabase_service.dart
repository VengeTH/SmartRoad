import "package:supabase_flutter/supabase_flutter.dart";
import "dart:io";
import "dart:typed_data";
import "../models/hazard.dart";
import "../models/user_profile.dart";
import "../core/config/env.dart";
import "../core/constants/app_constants.dart";
import "demo_service.dart";

/// * Supabase service for database operations
/// * Falls back to demo mode if Supabase is not configured
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal() {
    // * Check immediately if we should use demo mode
    if (!Env.validate()) {
      _isDemoMode = true;
      _demoService.enableDemoMode();
    }
  }
  
  bool _isDemoMode = false;
  bool _supabaseInitialized = false;
  final _demoService = DemoService();
  
  SupabaseClient? get client {
    // * Never access Supabase.instance if in demo mode
    if (_isDemoMode) {
      return null;
    }
    
    // * Only access Supabase if we've successfully initialized it
    if (!_supabaseInitialized) {
      return null;
    }
    
    // * At this point, we know Supabase is initialized, so it's safe to access
    return Supabase.instance.client;
  }
  
  /// * Enable demo mode manually
  void enableDemoMode() {
    _isDemoMode = true;
    _demoService.enableDemoMode();
  }
  
  /// * Initialize Supabase or enable demo mode
  Future<void> initialize() async {
    // * If already in demo mode, don't try to initialize Supabase
    if (_isDemoMode) {
      return;
    }
    
    if (!Env.validate()) {
      // * Enable demo mode if Supabase is not configured
      enableDemoMode();
      return;
    }
    
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
      _supabaseInitialized = true;
      _isDemoMode = false;
    } catch (e) {
      // * Fall back to demo mode on initialization error
      enableDemoMode();
    }
  }
  
  /// * Check if in demo mode
  bool get isDemoMode => _isDemoMode;
  
  // * Authentication Methods
  
  /// * Sign up with email and password
  Future<AuthResponse> signUp(String email, String password, String name) async {
    if (_isDemoMode) {
      final success = await _demoService.signUp(email, password, name);
      if (!success) {
        throw Exception("Demo signup failed");
      }
      // * Return mock AuthResponse
      return AuthResponse(
        session: null,
        user: User(
          id: DemoService.demoUserId,
          appMetadata: {},
          userMetadata: {'name': name},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    
    final response = await client!.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    return response;
  }
  
  /// * Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    if (_isDemoMode) {
      final success = await _demoService.signIn(email, password);
      if (!success) {
        throw Exception("Invalid email or password");
      }
      // * Return mock AuthResponse
      return AuthResponse(
        session: null,
        user: User(
          id: DemoService.demoUserId,
          appMetadata: {},
          userMetadata: {'name': DemoService.demoUserName},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    
    return await client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// * Sign out
  Future<void> signOut() async {
    if (_isDemoMode) {
      await _demoService.signOut();
      return;
    }
    
    await client!.auth.signOut();
  }
  
  /// * Get current user
  User? get currentUser {
    if (_isDemoMode) {
      if (_demoService.isAuthenticated) {
        return User(
          id: DemoService.demoUserId,
          appMetadata: {},
          userMetadata: {'name': DemoService.demoUserName},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
      }
      return null;
    }
    return client?.auth.currentUser;
  }
  
  /// * Get current user ID
  String? get currentUserId {
    if (_isDemoMode) {
      return _demoService.currentUserId;
    }
    return client?.auth.currentUser?.id;
  }
  
  /// * Check if user is authenticated
  bool get isAuthenticated {
    if (_isDemoMode) {
      return _demoService.isAuthenticated;
    }
    return client?.auth.currentUser != null;
  }
  
  // * Profile Methods
  
  /// * Get user profile
  Future<UserProfile?> getProfile(String userId) async {
    if (_isDemoMode) {
      return _demoService.demoUser;
    }
    
    final response = await client!
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return UserProfile.fromJson(response as Map<String, dynamic>);
  }
  
  /// * Update user profile
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    if (_isDemoMode) {
      await _demoService.updateDemoProfile(updates);
      return;
    }
    
    await client!
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
    if (_isDemoMode) {
      final allHazards = _demoService.getDemoHazards();
      return allHazards.skip(offset).take(limit).toList();
    }
    
    final response = await client!
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
    if (_isDemoMode) {
      return _demoService.getDemoHazardsInBounds(minLat, minLon, maxLat, maxLon);
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
    if (!isAuthenticated) {
      throw Exception("User must be authenticated to create hazards");
    }
    
    if (_isDemoMode) {
      return await _demoService.createDemoHazard(
        type: type,
        description: description,
        severity: severity,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
      );
    }
    
    final hazardData = {
      'type': type.value,
      'description': description.trim(),
      'severity': severity.value,
      'location': 'POINT($longitude $latitude)',
      if (imageUrl != null) 'image_url': imageUrl,
      if (stickerFlag != null) 'sticker_flag': stickerFlag,
    };
    
    final response = await client!
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
    if (_isDemoMode) {
      // * Demo mode doesn't support realtime updates
      return null;
    }
    
    final channel = client!.channel('hazards_channel');
    
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
    if (_isDemoMode) {
      // * In demo mode, return a placeholder URL
      return "https://via.placeholder.com/400x300?text=Demo+Image";
    }
    
    final bytes = await file.readAsBytes();
    final uint8List = Uint8List.fromList(bytes);
    await client!.storage
        .from(AppConstants.storageBucketName)
        .uploadBinary(fileName, uint8List);
    
    // * Get public URL
    final url = client!.storage
        .from(AppConstants.storageBucketName)
        .getPublicUrl(fileName);
    
    return url;
  }
  
  /// * Upload image file bytes
  Future<String> uploadImageBytes(Uint8List bytes, String fileName) async {
    if (_isDemoMode) {
      // * In demo mode, return a placeholder URL
      return "https://via.placeholder.com/400x300?text=Demo+Image";
    }
    
    await client!.storage
        .from(AppConstants.storageBucketName)
        .uploadBinary(fileName, bytes);
    
    final url = client!.storage
        .from(AppConstants.storageBucketName)
        .getPublicUrl(fileName);
    
    return url;
  }
}

