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

