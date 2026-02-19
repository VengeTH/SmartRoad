/// * Sticker Service
/// * Handles all sticker and HOA-related database operations
import '../models/sticker.dart';
import '../models/gate_access_log.dart';
import '../models/hoa_day_pass.dart';
import '../services/supabase_service.dart';

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
  
  /// * Log a gate access event (called by guard after scanning QR)
  /// * Returns the created log entry, or null on failure
  Future<GateAccessLog?> logGateAccess({
    required String hoaId,
    required String userId,
    required bool accessGranted,
    String? stickerId,
    String? scannedBy,
    GatePassMode passMode = GatePassMode.locationBound,
    String? notes,
  }) async {
    // * Always attempt to get the HOA name for the log
    final hoa = await getHOAById(hoaId);
    final hoaName = hoa?.name ?? 'Unknown HOA';
    final now = DateTime.now();

    if (_supabaseService.isDemoMode) {
      // * Demo mode: return an in-memory log entry without persisting
      return GateAccessLog(
        id: 'demo-log-${now.millisecondsSinceEpoch}',
        stickerId: stickerId,
        hoaId: hoaId,
        hoaName: hoaName,
        userId: userId,
        scannedBy: scannedBy,
        scanTime: now,
        accessGranted: accessGranted,
        passMode: passMode,
        notes: notes,
        createdAt: now,
      );
    }

    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final response = await client
          .from('gate_access_logs')
          .insert({
            'hoa_id': hoaId,
            'user_id': userId,
            'access_granted': accessGranted,
            if (stickerId != null) 'sticker_id': stickerId,
            if (scannedBy != null) 'scanned_by': scannedBy,
            'pass_mode': passMode.value,
            if (notes != null) 'notes': notes,
          })
          .select('''
            *,
            hoas:hoa_id (id, name)
          ''')
          .single();

      final data = Map<String, dynamic>.from(response);
      final hoaData = data['hoas'] as Map<String, dynamic>?;
      if (hoaData != null) data['hoa_name'] = hoaData['name'];
      return GateAccessLog.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// * Get gate access history for a user (transaction history)
  Future<List<GateAccessLog>> getUserAccessHistory(
    String userId, {
    int limit = 50,
  }) async {
    if (_supabaseService.isDemoMode) {
      return _getDemoAccessLogs(userId);
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      final response = await client
          .from('gate_access_logs')
          .select('''
            *,
            hoas:hoa_id (id, name)
          ''')
          .eq('user_id', userId)
          .order('scan_time', ascending: false)
          .limit(limit);

      return (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final hoaData = data['hoas'] as Map<String, dynamic>?;
        if (hoaData != null) data['hoa_name'] = hoaData['name'];
        return GateAccessLog.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// * Get access history for a specific HOA (guard/admin view)
  Future<List<GateAccessLog>> getHoaAccessHistory(
    String hoaId, {
    int limit = 100,
  }) async {
    if (_supabaseService.isDemoMode) {
      return _getDemoAccessLogs(null, hoaId: hoaId);
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      final response = await client
          .from('gate_access_logs')
          .select('''
            *,
            hoas:hoa_id (id, name)
          ''')
          .eq('hoa_id', hoaId)
          .order('scan_time', ascending: false)
          .limit(limit);

      return (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final hoaData = data['hoas'] as Map<String, dynamic>?;
        if (hoaData != null) data['hoa_name'] = hoaData['name'];
        return GateAccessLog.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// * Purchase a day pass for an HOA
  Future<HoaDayPass?> purchaseDayPass({
    required String userId,
    required String hoaId,
    GatePassMode passMode = GatePassMode.fullDay,
  }) async {
    final hoa = await getHOAById(hoaId);
    final hoaName = hoa?.name ?? 'Unknown HOA';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_supabaseService.isDemoMode) {
      return HoaDayPass(
        id: 'demo-daypass-${now.millisecondsSinceEpoch}',
        userId: userId,
        hoaId: hoaId,
        hoaName: hoaName,
        validDate: today,
        passMode: passMode,
        isActive: true,
        purchasedAt: now,
        createdAt: now,
      );
    }

    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final response = await client
          .from('hoa_day_passes')
          .upsert({
            'user_id': userId,
            'hoa_id': hoaId,
            'valid_date': dateStr,
            'pass_mode': passMode.value,
            'is_active': true,
          })
          .select('''
            *,
            hoas:hoa_id (id, name)
          ''')
          .single();

      final data = Map<String, dynamic>.from(response);
      final hoaData = data['hoas'] as Map<String, dynamic>?;
      if (hoaData != null) data['hoa_name'] = hoaData['name'];
      return HoaDayPass.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// * Get active day passes for a user
  Future<List<HoaDayPass>> getUserDayPasses(String userId) async {
    if (_supabaseService.isDemoMode) {
      return []; // * No demo day passes by default
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final response = await client
          .from('hoa_day_passes')
          .select('''
            *,
            hoas:hoa_id (id, name)
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .gte('valid_date', dateStr)
          .order('purchased_at', ascending: false);

      return (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final hoaData = data['hoas'] as Map<String, dynamic>?;
        if (hoaData != null) data['hoa_name'] = hoaData['name'];
        return HoaDayPass.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
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
        passMode: HOAPassMode.both,
        radiusMeters: 500,
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
        passMode: HOAPassMode.locationBound,
        radiusMeters: 400,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<GateAccessLog> _getDemoAccessLogs(String? userId, {String? hoaId}) {
    final now = DateTime.now();
    final uid = userId ?? 'demo-user-1';
    final logs = [
      GateAccessLog(
        id: 'demo-log-1',
        stickerId: 'demo-sticker-1',
        hoaId: 'demo-hoa-1',
        hoaName: 'BF Resort',
        userId: uid,
        scannedBy: 'demo-guard-1',
        scanTime: now.subtract(const Duration(hours: 2)),
        accessGranted: true,
        passMode: GatePassMode.locationBound,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      GateAccessLog(
        id: 'demo-log-2',
        stickerId: 'demo-sticker-2',
        hoaId: 'demo-hoa-2',
        hoaName: 'BF Homes',
        userId: uid,
        scannedBy: 'demo-guard-2',
        scanTime: now.subtract(const Duration(days: 1, hours: 3)),
        accessGranted: true,
        passMode: GatePassMode.fullDay,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      GateAccessLog(
        id: 'demo-log-3',
        stickerId: null,
        hoaId: 'demo-hoa-1',
        hoaName: 'BF Resort',
        userId: uid,
        scannedBy: 'demo-guard-1',
        scanTime: now.subtract(const Duration(days: 3)),
        accessGranted: false,
        passMode: GatePassMode.locationBound,
        notes: 'Expired QR code',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];

    if (hoaId != null) {
      return logs.where((l) => l.hoaId == hoaId).toList();
    }
    return logs;
  }
}

