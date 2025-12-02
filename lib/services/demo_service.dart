import "../models/hazard.dart";
import "../models/user_profile.dart";
import "dart:math" as math;

/// * Demo service for running app without Supabase
/// * Provides mock data and authentication
class DemoService {
  static final DemoService _instance = DemoService._internal();
  factory DemoService() => _instance;
  DemoService._internal();
  
  bool _isDemoMode = false;
  String? _demoUserId;
  UserProfile? _demoUser;
  final List<Hazard> _demoHazards = [];
  
  /// * Enable demo mode
  void enableDemoMode() {
    _isDemoMode = true;
    // * Auto-authenticate demo user
    _demoUserId = demoUserId;
    // * Initialize demo data (creates demo user profile)
    _initializeDemoData();
  }
  
  /// * Check if demo mode is enabled
  bool get isDemoMode => _isDemoMode;
  
  /// * Demo user credentials
  static const String demoEmail = "demo@smartroad.app";
  static const String demoPassword = "DemoPass123!";
  static const String demoUserId = "demo-user-123";
  static const String demoUserName = "Demo User";
  
  /// * Initialize demo data
  void _initializeDemoData() {
    // * Auto-authenticate in demo mode
    _demoUserId = demoUserId;
    // * Create demo user profile
    _demoUser = UserProfile(
      id: demoUserId,
      email: demoEmail,
      name: demoUserName,
      photoUrl: null,
      reporterLevel: ReporterLevel.expert,
      validReportsCount: 42,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );
    
    // * Create demo hazards
    final random = math.Random();
    final now = DateTime.now();
    
    // * Sample locations (Manila area)
    final locations = [
      (14.5995, 120.9842), // Manila
      (14.5506, 121.0263), // Makati
      (14.6760, 121.0437), // Quezon City
      (14.5143, 121.0500), // Pasig
      (14.4793, 121.0198), // Mandaluyong
    ];
    
    final types = HazardType.values;
    final severities = SeverityLevel.values;
    
    final descriptions = [
      "Large pothole on the main road causing vehicle damage",
      "Flooding after heavy rain, water level about 30cm",
      "Road closure due to construction work",
      "Accident scene, traffic backed up for 2km",
      "Landslide blocking one lane, proceed with caution",
      "Roadblock due to fallen tree, use alternate route",
      "Deep pothole near intersection, multiple vehicles affected",
      "Severe flooding, road impassable for small vehicles",
      "Major accident, emergency services on scene",
      "Complete road closure for maintenance",
    ];
    
    for (int i = 0; i < 15; i++) {
      final location = locations[random.nextInt(locations.length)];
      final type = types[random.nextInt(types.length)];
      final severity = severities[random.nextInt(severities.length)];
      final description = descriptions[random.nextInt(descriptions.length)];
      final hoursAgo = random.nextInt(72); // * Within last 3 days
      
      _demoHazards.add(Hazard(
        id: "demo-hazard-$i",
        userId: demoUserId,
        type: type,
        description: description,
        severity: severity,
        latitude: location.$1 + (random.nextDouble() - 0.5) * 0.1,
        longitude: location.$2 + (random.nextDouble() - 0.5) * 0.1,
        imageUrl: null,
        stickerFlag: null,
        createdAt: now.subtract(Duration(hours: hoursAgo)),
        updatedAt: now.subtract(Duration(hours: hoursAgo)),
        userName: demoUserName,
        userPhotoUrl: null,
      ));
    }
    
    // * Sort by creation date (newest first)
    _demoHazards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  /// * Demo authentication
  Future<bool> signIn(String email, String password) async {
    if (!_isDemoMode) return false;
    
    if (email == demoEmail && password == demoPassword) {
      _demoUserId = demoUserId;
      return true;
    }
    return false;
  }
  
  Future<bool> signUp(String email, String password, String name) async {
    if (!_isDemoMode) return false;
    // * In demo mode, signup also works
    _demoUserId = demoUserId;
    return true;
  }
  
  Future<void> signOut() async {
    if (!_isDemoMode) return;
    _demoUserId = null;
  }
  
  String? get currentUserId => _isDemoMode ? _demoUserId : null;
  
  bool get isAuthenticated => _isDemoMode && _demoUserId != null;
  
  /// * Get demo user profile
  UserProfile? get demoUser => _isDemoMode ? _demoUser : null;
  
  /// * Get demo hazards
  List<Hazard> getDemoHazards() {
    if (!_isDemoMode) return [];
    return List.from(_demoHazards);
  }
  
  /// * Get demo hazards in bounds
  List<Hazard> getDemoHazardsInBounds(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) {
    if (!_isDemoMode) return [];
    
    return _demoHazards.where((hazard) {
      return hazard.latitude >= minLat &&
          hazard.latitude <= maxLat &&
          hazard.longitude >= minLon &&
          hazard.longitude <= maxLon;
    }).toList();
  }
  
  /// * Create demo hazard
  Future<Hazard> createDemoHazard({
    required HazardType type,
    required String description,
    required SeverityLevel severity,
    required double latitude,
    required double longitude,
    String? imageUrl,
  }) async {
    if (!_isDemoMode) {
      throw Exception("Demo mode not enabled");
    }
    
    final hazard = Hazard(
      id: "demo-hazard-${DateTime.now().millisecondsSinceEpoch}",
      userId: demoUserId,
      type: type,
      description: description,
      severity: severity,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      stickerFlag: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      userName: demoUserName,
      userPhotoUrl: null,
    );
    
    _demoHazards.insert(0, hazard);
    return hazard;
  }
  
  /// * Update demo profile
  Future<void> updateDemoProfile(Map<String, dynamic> updates) async {
    if (!_isDemoMode || _demoUser == null) return;
    
    _demoUser = UserProfile(
      id: _demoUser!.id,
      email: _demoUser!.email,
      name: updates['name'] as String? ?? _demoUser!.name,
      photoUrl: updates['photo_url'] as String? ?? _demoUser!.photoUrl,
      reporterLevel: _demoUser!.reporterLevel,
      validReportsCount: _demoUser!.validReportsCount,
      createdAt: _demoUser!.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}




