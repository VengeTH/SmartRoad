/// * RainViewer Service
/// * Fetches available radar timestamps from RainViewer API
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

/// * RainViewer service for fetching available radar timestamps
class RainViewerService {
  static final RainViewerService _instance = RainViewerService._internal();
  factory RainViewerService() => _instance;
  RainViewerService._internal();
  
  // * RainViewer API endpoint
  static const String _apiUrl = "https://api.rainviewer.com/public/weather-maps.json";
  
  // * Cache for available timestamps
  List<int>? _cachedTimestamps;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// * Fetch available radar timestamps
  /// * 
  /// * Returns list of Unix timestamps (in seconds) for available radar frames
  Future<List<int>?> getAvailableTimestamps() async {
    // * Check cache
    if (_cachedTimestamps != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) {
        return _cachedTimestamps;
      }
    }
    
    const maxRetries = 3;
    const initialRetryDelay = Duration(seconds: 2);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(_apiUrl),
          headers: {
            'User-Agent': 'SmartRoad App',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          // * RainViewer API structure: { "version": "2.0", "generated": 1234567890, "host": "...", "radar": { "past": [...] } }
          final radar = data['radar'] as Map<String, dynamic>?;
          final past = radar?['past'] as List<dynamic>?;
          
          if (past != null && past.isNotEmpty) {
            final timestamps = <int>[];
            
            for (final item in past) {
              if (item is Map<String, dynamic>) {
                final time = item['time'] as int?;
                if (time != null) {
                  timestamps.add(time);
                }
              }
            }
            
            if (timestamps.isNotEmpty) {
              // * Cache the result
              _cachedTimestamps = timestamps;
              _cacheTimestamp = DateTime.now();
              
              if (attempt > 0) {
                debugPrint("🌧️ [RainViewerService] Fetched ${timestamps.length} radar timestamps after ${attempt + 1} attempts");
              } else {
                debugPrint("🌧️ [RainViewerService] Fetched ${timestamps.length} radar timestamps (latest: ${timestamps.first})");
              }
              return timestamps;
            }
          } else {
            debugPrint("⚠️ [RainViewerService] No past radar data available");
            return null;
          }
        } else if (response.statusCode == 429) {
          // * Rate limited - retry with exponential backoff
          if (attempt < maxRetries - 1) {
            final delay = Duration(milliseconds: initialRetryDelay.inMilliseconds * (1 << attempt));
            debugPrint("⚠️ [RainViewerService] Rate limited (429), retrying after ${delay.inSeconds}s");
            await Future.delayed(delay);
            continue;
          }
        } else {
          debugPrint("❌ [RainViewerService] API error: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 200))}");
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: initialRetryDelay.inMilliseconds * (1 << attempt)));
            continue;
          }
        }
      } catch (e) {
        if (attempt < maxRetries - 1) {
          final delay = Duration(milliseconds: initialRetryDelay.inMilliseconds * (1 << attempt));
          debugPrint("⚠️ [RainViewerService] Error fetching timestamps (attempt ${attempt + 1}/$maxRetries), retrying after ${delay.inSeconds}s: $e");
          await Future.delayed(delay);
        } else {
          debugPrint("❌ [RainViewerService] Error fetching timestamps after $maxRetries attempts: $e");
        }
      }
    }
    
    // * Return cached data if available, even if expired
    if (_cachedTimestamps != null && _cachedTimestamps!.isNotEmpty) {
      debugPrint("⚠️ [RainViewerService] Using cached timestamps due to API failure");
      return _cachedTimestamps;
    }
    
    return null;
  }
  
  /// * Get the closest available timestamp to a target time
  /// * 
  /// * [targetTimestamp] - Target Unix timestamp in seconds
  /// * Returns the closest available timestamp, or null if none found
  Future<int?> getClosestTimestamp(int targetTimestamp) async {
    final timestamps = await getAvailableTimestamps();
    if (timestamps == null || timestamps.isEmpty) {
      return null;
    }
    
    // * Find closest timestamp
    int? closest;
    int minDiff = 999999999;
    
    for (final ts in timestamps) {
      final diff = (ts - targetTimestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = ts;
      }
    }
    
    return closest;
  }
  
  /// * Get timestamp for a specific frame
  /// * 
  /// * [frame] - Frame index (0 = most recent, higher = older)
  /// * Returns timestamp for the frame, or null if not available
  Future<int?> getTimestampForFrame(int frame) async {
    final timestamps = await getAvailableTimestamps();
    if (timestamps == null || timestamps.isEmpty) {
      return null;
    }
    
    // * Sort timestamps (newest first)
    timestamps.sort((a, b) => b.compareTo(a));
    
    // * Return timestamp at frame index (0 = most recent)
    if (frame >= 0 && frame < timestamps.length) {
      return timestamps[frame];
    }
    
    return null;
  }
  
  /// * Clear cache
  void clearCache() {
    _cachedTimestamps = null;
    _cacheTimestamp = null;
  }
}

