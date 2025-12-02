/// * Sticker Service
/// * Handles all sticker and HOA-related database operations
import "../models/sticker.dart";
import "../services/supabase_service.dart";

class StickerService {
  final SupabaseService _supabaseService = SupabaseService();
  
  /// * Get all stickers for a user
  Future<List<Sticker>> getUserStickers(String userId) async {
    if (_supabaseService.isDemoMode) {
      // * Return demo stickers
      return _getDemoStickers(userId);
    }
    
    final client = _supabaseService.client;
    if (client == null) {
      return [];
    }
    
    try {
      final response = await client
          .from('user_stickers')
          .select('''
            *,
            hoas:hoa_id (
              id,
              name,
              description,
              latitude,
              longitude,
              access_type,
              is_active
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final List<Sticker> stickers = [];
      for (final item in response) {
        final stickerData = Map<String, dynamic>.from(item);
        final hoaData = stickerData['hoas'] != null 
            ? Map<String, dynamic>.from(stickerData['hoas'] as Map)
            : null;
        
        if (hoaData != null) {
          stickerData['hoa_name'] = hoaData['name'];
        }
        
        stickers.add(Sticker.fromJson(stickerData));
      }
      
      return stickers;
    } catch (e) {
      // * Return empty list on error
      return [];
    }
  }
  
  /// * Get active (valid) stickers for a user
  Future<List<Sticker>> getActiveUserStickers(String userId) async {
    final allStickers = await getUserStickers(userId);
    return allStickers.where((sticker) => sticker.isValid).toList();
  }
  
  /// * Get sticker by ID
  Future<Sticker?> getStickerById(String stickerId) async {
    if (_supabaseService.isDemoMode) {
      // * Return demo sticker if found
      final demoStickers = _getDemoStickers(_supabaseService.currentUserId ?? "");
      return demoStickers.firstWhere(
        (s) => s.id == stickerId,
        orElse: () => throw Exception("Sticker not found"),
      );
    }
    
    final client = _supabaseService.client;
    if (client == null) {
      return null;
    }
    
    try {
      final response = await client
          .from('user_stickers')
          .select('''
            *,
            hoas:hoa_id (
              id,
              name,
              description,
              latitude,
              longitude,
              access_type,
              is_active
            )
          ''')
          .eq('id', stickerId)
          .maybeSingle();
      
      if (response == null) return null;
      
      final stickerData = Map<String, dynamic>.from(response);
      final hoaData = stickerData['hoas'] != null
          ? Map<String, dynamic>.from(stickerData['hoas'] as Map)
          : null;
      
      if (hoaData != null) {
        stickerData['hoa_name'] = hoaData['name'];
      }
      
      return Sticker.fromJson(stickerData);
    } catch (e) {
      return null;
    }
  }
  
  /// * Validate gate pass QR code
  /// * Returns the sticker if valid, null otherwise
  Future<Sticker?> validateGatePass(GatePassData gatePassData) async {
    // * Check if QR code is not too old (5 minutes max)
    if (!gatePassData.isValid()) {
      return null;
    }
    
    // * Get the sticker
    final sticker = await getStickerById(gatePassData.stickerId);
    if (sticker == null) {
      return null;
    }
    
    // * Verify user ID matches
    if (sticker.userId != gatePassData.userId) {
      return null;
    }
    
    // * Check if sticker is valid (active and not expired)
    if (!sticker.isValid) {
      return null;
    }
    
    return sticker;
  }
  
  /// * Get all HOAs (for admin/guard view)
  Future<List<HOA>> getAllHOAs() async {
    if (_supabaseService.isDemoMode) {
      return _getDemoHOAs();
    }
    
    final client = _supabaseService.client;
    if (client == null) {
      return [];
    }
    
    try {
      final response = await client
          .from('hoas')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);
      
      return (response as List)
          .map<HOA>((item) => HOA.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// * Get HOA by ID
  Future<HOA?> getHOAById(String hoaId) async {
    if (_supabaseService.isDemoMode) {
      final demoHOAs = _getDemoHOAs();
      return demoHOAs.firstWhere(
        (h) => h.id == hoaId,
        orElse: () => throw Exception("HOA not found"),
      );
    }
    
    final client = _supabaseService.client;
    if (client == null) {
      return null;
    }
    
    try {
      final response = await client
          .from('hoas')
          .select()
          .eq('id', hoaId)
          .maybeSingle();
      
      if (response == null) return null;
      return HOA.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      return null;
    }
  }
  
  /// * Create a physical sticker (uploaded by user, verified by AI)
  /// * 
  /// * [userId] - The user ID
  /// * [hoaId] - The HOA ID
  /// * [stickerNumber] - The sticker number (optional)
  /// * [stickerPhotoUrl] - The URL of the uploaded sticker photo
  /// * [issuedAt] - When the sticker was issued
  /// * [expiresAt] - When the sticker expires
  /// * 
  /// * Returns the created sticker
  Future<Sticker> createPhysicalSticker({
    required String userId,
    required String hoaId,
    String? stickerNumber,
    required String stickerPhotoUrl,
    required DateTime issuedAt,
    required DateTime expiresAt,
  }) async {
    if (_supabaseService.isDemoMode) {
      // * In demo mode, return a demo sticker
      final now = DateTime.now();
      return Sticker(
        id: "demo-physical-sticker-${DateTime.now().millisecondsSinceEpoch}",
        userId: userId,
        hoaId: hoaId,
        hoaName: "Demo HOA",
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        isActive: true,
        isPhysicalSticker: true,
        verifiedByAi: true,
        stickerPhotoUrl: stickerPhotoUrl,
        createdAt: now,
        updatedAt: now,
      );
    }
    
    final client = _supabaseService.client;
    if (client == null) {
      throw Exception("Supabase client not available");
    }
    
    try {
      // * Get HOA name
      final hoa = await getHOAById(hoaId);
      if (hoa == null) {
        throw Exception("HOA not found");
      }
      
      // * Insert the physical sticker
      final response = await client
          .from('user_stickers')
          .insert({
            'user_id': userId,
            'hoa_id': hoaId,
            'issued_at': issuedAt.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'is_active': true,
            'is_physical_sticker': true,
            'verified_by_ai': true,
            'sticker_photo_url': stickerPhotoUrl,
          })
          .select('''
            *,
            hoas:hoa_id (
              id,
              name,
              description,
              latitude,
              longitude,
              is_active
            )
          ''')
          .single();
      
      final stickerData = Map<String, dynamic>.from(response);
      final hoaData = stickerData['hoas'] != null
          ? Map<String, dynamic>.from(stickerData['hoas'] as Map)
          : null;
      
      if (hoaData != null) {
        stickerData['hoa_name'] = hoaData['name'];
      }
      
      return Sticker.fromJson(stickerData);
    } catch (e) {
      throw Exception("Failed to create physical sticker: $e");
    }
  }
  
  // * Demo Mode Methods
  
  List<Sticker> _getDemoStickers(String userId) {
    // * Return demo stickers for testing
    final now = DateTime.now();
    return [
      Sticker(
        id: "demo-sticker-1",
        userId: userId,
        hoaId: "demo-hoa-1",
        hoaName: "BF Resort",
        issuedAt: now.subtract(const Duration(days: 30)),
        expiresAt: now.add(const Duration(days: 335)),
        isActive: true,
        isPhysicalSticker: false,
        verifiedByAi: false,
        stickerPhotoUrl: null,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
      Sticker(
        id: "demo-sticker-2",
        userId: userId,
        hoaId: "demo-hoa-2",
        hoaName: "BF Homes",
        issuedAt: now.subtract(const Duration(days: 15)),
        expiresAt: now.add(const Duration(days: 350)),
        isActive: true,
        isPhysicalSticker: false,
        verifiedByAi: false,
        stickerPhotoUrl: null,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }
  
  List<HOA> _getDemoHOAs() {
    final now = DateTime.now();
    return [
      HOA(
        id: "demo-hoa-1",
        name: "BF Resort",
        description: "BF Resort Village",
        latitude: 14.4244,
        longitude: 120.9883,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      HOA(
        id: "demo-hoa-2",
        name: "BF Homes",
        description: "BF Homes Parañaque",
        latitude: 14.5000,
        longitude: 121.0000,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

