import "dart:convert";
import "package:hive_flutter/hive_flutter.dart";
import "../models/hazard.dart";

/// * Offline cache service using Hive
class OfflineCacheService {
  static const String _hazardsBoxName = 'hazards_cache';
  static const String _pendingReportsBoxName = 'pending_reports';
  
  static Box? _hazardsBox;
  static Box? _pendingReportsBox;
  
  /// * Initialize Hive and open boxes
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    _hazardsBox = await Hive.openBox(_hazardsBoxName);
    _pendingReportsBox = await Hive.openBox(_pendingReportsBoxName);
  }
  
  // * Hazards Cache Methods
  
  /// * Cache hazards list
  Future<void> cacheHazards(List<Hazard> hazards) async {
    if (_hazardsBox == null) await initialize();
    
    final hazardsJson = hazards.map((h) => {
      'id': h.id,
      'user_id': h.userId,
      'type': h.type.value,
      'description': h.description,
      'severity': h.severity.value,
      'latitude': h.latitude,
      'longitude': h.longitude,
      'image_url': h.imageUrl,
      'sticker_flag': h.stickerFlag,
      'created_at': h.createdAt.toIso8601String(),
      'updated_at': h.updatedAt.toIso8601String(),
      'user_name': h.userName,
      'user_photo_url': h.userPhotoUrl,
    }).toList();
    
    await _hazardsBox!.put('hazards', jsonEncode(hazardsJson));
    await _hazardsBox!.put('last_updated', DateTime.now().toIso8601String());
  }
  
  /// * Get cached hazards
  List<Hazard>? getCachedHazards() {
    if (_hazardsBox == null) return null;
    
    final hazardsJson = _hazardsBox!.get('hazards');
    if (hazardsJson == null) return null;
    
    try {
      final List<dynamic> decoded = jsonDecode(hazardsJson as String);
      return decoded.map((json) {
        // * Convert to format expected by Hazard.fromJson
        return Hazard.fromJson({
          'id': json['id'],
          'user_id': json['user_id'],
          'type': json['type'],
          'description': json['description'],
          'severity': json['severity'],
          'location': {
            'type': 'Point',
            'coordinates': [json['longitude'], json['latitude']],
          },
          'image_url': json['image_url'],
          'sticker_flag': json['sticker_flag'],
          'created_at': json['created_at'],
          'updated_at': json['updated_at'],
          'user_name': json['user_name'],
          'user_photo_url': json['user_photo_url'],
        });
      }).toList();
    } catch (e) {
      return null;
    }
  }
  
  /// * Get last cache update time
  DateTime? getLastCacheTime() {
    if (_hazardsBox == null) return null;
    
    final timeStr = _hazardsBox!.get('last_updated') as String?;
    if (timeStr == null) return null;
    
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }
  
  // * Pending Reports Methods
  
  /// * Add pending report (for offline submission)
  Future<void> addPendingReport(Map<String, dynamic> reportData) async {
    if (_pendingReportsBox == null) await initialize();
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _pendingReportsBox!.put(id, jsonEncode(reportData));
  }
  
  /// * Get all pending reports
  List<Map<String, dynamic>> getPendingReports() {
    if (_pendingReportsBox == null) return [];
    
    final reports = <Map<String, dynamic>>[];
    for (final key in _pendingReportsBox!.keys) {
      final data = _pendingReportsBox!.get(key);
      if (data != null) {
        try {
          reports.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (e) {
          // * Skip invalid entries
        }
      }
    }
    
    return reports;
  }
  
  /// * Remove pending report
  Future<void> removePendingReport(String id) async {
    if (_pendingReportsBox == null) return;
    await _pendingReportsBox!.delete(id);
  }
  
  /// * Clear all cache
  Future<void> clearCache() async {
    if (_hazardsBox != null) {
      await _hazardsBox!.clear();
    }
    if (_pendingReportsBox != null) {
      await _pendingReportsBox!.clear();
    }
  }
}

